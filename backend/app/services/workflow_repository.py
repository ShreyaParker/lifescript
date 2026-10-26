import hashlib
import json
from datetime import datetime, timezone

from fastapi import HTTPException

from app.core.config import settings


def rpc_error(exc):
    # Never surface provider/database exception strings to clients.
    message = str(exc)
    if "upload_quota_exceeded" in message:
        return HTTPException(429,"Attachment storage limit reached")
    if "asset_in_use" in message:
        return HTTPException(409,"This attachment is used by a saved reflection. Delete that reflection first.")
    if "rule_quota_exceeded" in message:
        return HTTPException(429,"Automation rule limit reached")
    if "quota_exceeded" in message:
        return HTTPException(429, "Hourly processing limit reached. Please try again later.")
    if "calendar_not_connected" in message:
        return HTTPException(409, "Connect your calendar before approving an event")
    if "not_found" in message or "asset_not_found" in message:
        return HTTPException(404, "Record not found")
    if any(code in message for code in ("conflict", "invalid_selection")):
        return HTTPException(409, "The operation conflicts with current state")
    return HTTPException(503, "Storage operation unavailable")


class WorkflowRepository:
    def __init__(self, db):
        self.db = db

    def rpc(self, name, params):
        try:
            return self.db.rpc(name, params).execute().data
        except Exception as exc:
            raise rpc_error(exc) from None

    def create(self, owner, payload, key):
        serialized = payload.model_dump(mode="json")
        digest = hashlib.sha256(json.dumps(serialized, sort_keys=True).encode()).hexdigest()
        return self.rpc("create_entry_run", {
            "p_owner": owner, "p_content": payload.content, "p_key": key,
            "p_digest": digest, "p_assets": serialized["asset_ids"], "p_timezone": payload.timezone,
        })

    def owned_run(self, owner, run_id):
        rows = self.db.table("workflow_runs").select("*").eq("id", str(run_id)).eq("user_id", owner).limit(1).execute().data
        if not rows:
            raise HTTPException(404, "Run not found")
        return rows[0]

    def claim(self):
        return self.rpc("claim_workflow", {"p_lease_seconds": settings.WORKER_LEASE_SECONDS,
                                           "p_max_attempts": settings.MAX_RUN_ATTEMPTS})

    def update_claim(self, run, values):
        values["updated_at"] = datetime.now(timezone.utc).isoformat()
        result = (self.db.table("workflow_runs").update(values).eq("id", run["id"])
                  .eq("user_id", run["user_id"]).eq("lease_token", run["lease_token"])
                  .eq("status", "running").execute().data)
        if not result:
            raise RuntimeError("lease_lost")

    def resume(self, owner, run_id, version, data, expected):
        return self.rpc("resume_workflow", {"p_owner": owner, "p_run": str(run_id),
            "p_version": version, "p_data": data, "p_expected": expected})

    def commit(self, run, decision):
        return self.rpc("commit_plan", {"p_owner": run["user_id"], "p_run": run["id"],
                                       "p_token": run["lease_token"], "p_decision": decision})

    def context(self, run):
        owner = run["user_id"]
        entries = self.db.table("journal_entries").select("*").eq("id", run["entry_id"]).eq("user_id", owner).limit(1).execute().data
        if not entries:
            raise RuntimeError("source_deleted")
        profiles = self.db.table("users").select("macro_goals").eq("id", owner).limit(1).execute().data
        tasks = self.db.table("tasks").select("id,title,status").eq("user_id", owner).eq("status", "pending").limit(50).execute().data
        objectives = self.db.table("objectives").select("title,kind,status").eq("user_id", owner).limit(200).execute().data or []
        goals = (profiles[0].get("macro_goals", []) if profiles else [])
        return entries[0], (list(dict.fromkeys(row["title"] for row in objectives if row["status"] == "active")) if objectives else goals), tasks or []

    def search(self, owner, query, vector=None, model=None, exclude=None):
        return self.rpc("search_memory", {"p_owner": owner, "p_query": query[:2000],
            "p_vector": vector, "p_model": model, "p_exclude": exclude}) or []

    def index(self, run, sources, provider):
        chunks = []
        for source in sources:
            for offset in range(0,len(source["content"]),1000):
                chunks.append({"source_id": f"{source['source_id']}:chunk:{offset}", "content": source["content"][offset:offset+1200]})
        chunks=chunks[:32]
        try:
            vectors=provider.embed_many([chunk["content"] for chunk in chunks])
        except Exception:
            vectors=[None]*len(chunks)  # Keyword retrieval remains available.
        for chunk,vector in zip(chunks,vectors):
            self.rpc("index_memory_chunk", {"p_owner":run["user_id"],"p_run":run["id"],
                "p_revision":run.get("graph_revision",1),"p_source":chunk["source_id"],"p_content":chunk["content"],
                "p_vector":vector,"p_model":provider.embedding_model if vector else None})


def public_run(run):
    allowed = ("id", "entry_id", "status", "proposal", "questions", "version", "result",
               "error_code", "created_at", "updated_at", "sources")
    return {key: run.get(key) for key in allowed}
