"""Run with python -m app.worker. No hosted inference or writes occur at import."""
import logging
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

from langgraph.types import Command

from app.core.config import settings
from app.core.db import get_db
from app.services.asset_service import extract_asset
from app.services.model_provider import ModelProvider
from app.services.planning_graph import build_graph
from app.services.workflow_repository import WorkflowRepository

log = logging.getLogger("lifescript.worker")


@contextmanager
def checkpoint_store():
    if settings.CHECKPOINT_DATABASE_URL:
        from langgraph.checkpoint.postgres import PostgresSaver
        import psycopg
        from psycopg.rows import dict_row
        with psycopg.connect(settings.CHECKPOINT_DATABASE_URL, autocommit=True,
            prepare_threshold=0, row_factory=dict_row, options="-csearch_path=lifescript_private") as connection:
            if not connection.execute("select to_regnamespace('lifescript_private') as schema").fetchone()["schema"]:
                raise RuntimeError("Apply private checkpoint schema migration first")
            saver = PostgresSaver(connection)
            saver.setup()
            yield saver
    else:
        from langgraph.checkpoint.sqlite import SqliteSaver
        settings.DATA_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
        with SqliteSaver.from_conn_string(str(settings.DATA_DIR / "checkpoints.sqlite")) as saver:
            yield saver


def load_sources(repo, run, provider):
    entry, goals, tasks = repo.context(run)
    if run.get("source_overrides"):
        return entry, goals, tasks, run["source_overrides"]
    sources = [{"source_id": run["entry_id"], "content": entry["content"]}]
    for asset_id in run["asset_ids"]:
        assets = repo.db.table("assets").select("*").eq("id", asset_id).eq("user_id", run["user_id"]).limit(1).execute().data
        if not assets:
            raise ValueError("source_deleted")
        asset = assets[0]
        data = repo.db.storage.from_(settings.STORAGE_BUCKET).download(asset["storage_path"])
        sources.extend(extract_asset(data, asset["mime_type"], asset["id"], provider))
    # Bound model context even if the accepted file has many pages/segments.
    # Reserve room for a later user clarification while keeping total context bounded.
    bounded, remaining = [], 26000
    for source in sources:
        content = source["content"][:remaining]
        if content.strip():
            bounded.append({**source, "content": content})
            remaining -= len(content)
        if remaining <= 0:
            break
    return entry, goals, tasks, bounded


def process_run(repo, run, provider, graph):
    thread_id = f"{run['user_id']}:{run['id']}"
    if run.get("graph_revision", 1)>1:
        thread_id += f":{run['graph_revision']}"
    config = {"configurable": {"thread_id": thread_id}, "recursion_limit": 12}
    snapshot = graph.get_state(config)
    if not snapshot.values:
        entry, goals, tasks, sources = load_sources(repo, run, provider)
        vector = None
        try:
            vector = provider.embed(entry["content"][:3000])
        except Exception:
            pass
        memory = repo.search(run["user_id"], entry["content"], vector, provider.embedding_model, run["entry_id"])
        from app.services.progress_service import weekly_counts
        metrics=weekly_counts(repo.db,run["user_id"]) if hasattr(repo,"db") else {}
        input_state = {"owner": run["user_id"], "entry_id": run["entry_id"], "content": entry["content"],
            "timezone": run["timezone"], "reference_time": entry["created_at"], "goals": goals,
            "existing_tasks": tasks, "sources": sources, "memory": memory,
            "workflow_kind":run.get("workflow_kind","planning"),"progress":metrics}
    elif run.get("resume_data") and (
        ("answer" in run["resume_data"] and "clarify" in snapshot.next) or
        ("decision" in run["resume_data"] and "review" in snapshot.next)
    ):
        input_state = Command(resume=run["resume_data"])
    else:
        input_state = None  # Resume a checkpointed node after transient failure.
    # A completed checkpoint may precede a failed task-commit RPC. Reuse it rather
    # than sending a resume command to a graph with no pending interrupt.
    current=repo.owned_run(run["user_id"],run["id"])
    if current["status"]!="running" or current["lease_token"]!=run["lease_token"]:
        raise RuntimeError("lease_lost")
    result = dict(snapshot.values) if snapshot.values and not snapshot.next else graph.invoke(input_state, config)
    if result.get("__interrupt__"):
        value = result["__interrupt__"][0].value
        status = "awaiting_review" if value["kind"] == "review" else "awaiting_clarification"
        repo.update_claim(run, {"status": status, "proposal": result.get("plan"),
            "questions": value.get("questions", []), "sources": result.get("sources", []),
            "resume_data": None, "lease_until": None, "error_code": None})
    else:
        # Transactional RPC commits selected tasks and terminal status together.
        # A crash between graph completion and RPC is safe: completed checkpoint is replayed.
        # The reviewed database proposal is authoritative after user edits.
        from app.schemas.workflow import Plan
        from app.services.planning_graph import validate_plan
        current = repo.owned_run(run["user_id"], run["id"])
        _, _, current_tasks = repo.context(run)
        validate_plan(Plan.model_validate(current["proposal"]), current["sources"], current_tasks)
        repo.commit(run, result["decision"])
    # Index once after review/clarification, not as a prerequisite for journal saving.
    try:
        repo.index(run, result.get("sources", []), provider)
    except Exception:
        log.warning("memory_index_deferred", extra={"run_id": run["id"]})


def work_once(repo, provider, graph):
    run = repo.claim()
    if not run:
        return False
    stopped = threading.Event()

    def renew():
        while not stopped.wait(max(10, settings.WORKER_LEASE_SECONDS / 3)):
            try:
                repo.update_claim(run, {"lease_until": (datetime.now(timezone.utc) + timedelta(seconds=settings.WORKER_LEASE_SECONDS)).isoformat()})
            except Exception:
                return

    heartbeat = threading.Thread(target=renew, daemon=True)
    heartbeat.start()
    try:
        process_run(repo, run, provider, graph)
    except Exception as exc:
        safe_file_errors={"scanned_pdf_requires_ocr","pdf_encrypted_or_page_limit","audio_duration_limit",
                          "unsupported_file_format","media_engine_unavailable"}
        error_code=("provider_quota_exceeded" if getattr(exc, "code", None) == 429 else
                    str(exc) if str(exc) in safe_file_errors else "processing_failed")
        retry = error_code not in safe_file_errors and run["attempts"] < settings.MAX_RUN_ATTEMPTS
        try:
            repo.update_claim(run, {"status": "queued" if retry else "failed", "error_code": error_code,
                "available_at": (datetime.now(timezone.utc) + timedelta(seconds=300 if error_code == "provider_quota_exceeded" else 2 ** run["attempts"] * 10)).isoformat(),
                "lease_until": None})
        except Exception:
            pass  # Another worker/deletion may have invalidated this lease.
        log.warning("workflow_attempt_failed", extra={"run_id": run["id"], "attempt": run["attempts"]})
    finally:
        stopped.set()
        heartbeat.join(timeout=1)
    return True


def main():
    from app.core.logging import configure_logging
    configure_logging()
    repo, provider = WorkflowRepository(get_db()), ModelProvider()
    rows=repo.db.table("app_schema_metadata").select("version").eq("singleton",True).limit(1).execute().data
    if not rows or rows[0]["version"]<12:
        raise RuntimeError("Apply ordered migrations before starting the worker")
    with checkpoint_store() as saver:
        graph = build_graph(provider, saver)
        log.info("worker_ready")
        while True:
            try:
                cleanup_retention(repo, saver)
                repo.rpc("queue_orphan_assets", {})
                repo.rpc("schedule_automations", {})
                from app.services.calendar_service import process_calendar_action
                process_calendar_action(repo)
                if not work_once(repo, provider, graph):
                    time.sleep(settings.WORKER_POLL_SECONDS)
            except KeyboardInterrupt:
                break
            except Exception:
                log.warning("worker_storage_unavailable")
                time.sleep(settings.WORKER_POLL_SECONDS)


def cleanup_retention(repo, saver):
    jobs = (repo.db.table("retention_jobs").select("*")
            .lte("available_at", datetime.now(timezone.utc).isoformat()).limit(20).execute().data or [])
    for job in jobs:
        # Delayed beyond active worker leases: prevents an in-flight extraction
        # from recreating a just-deleted checkpoint before it observes deletion.
        if job["thread_prefix"]:
            saver.delete_thread(job["thread_prefix"])
        if job["storage_paths"]:
            repo.db.storage.from_(settings.STORAGE_BUCKET).remove(job["storage_paths"])
        repo.db.table("retention_jobs").delete().eq("id", job["id"]).execute()


if __name__ == "__main__":
    main()
