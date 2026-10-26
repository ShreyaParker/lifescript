import io
import re
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, File, Header, HTTPException, Query, UploadFile
from fastapi.responses import StreamingResponse
from supabase import Client

from app.core.config import settings
from app.core.db import get_db
from app.core.security import get_current_user
from app.schemas.workflow import AutomationRequest, AutomationToggle, Clarification, Decision, EntryRequest, ProposalEdit, SourceCorrection
from app.services.planning_graph import validate_plan
from app.services.asset_service import validate_asset
from app.services.workflow_repository import WorkflowRepository, public_run

router = APIRouter()


def request_key(value: str):
    if not re.fullmatch(r"[A-Za-z0-9:_-]{8,160}", value):
        raise HTTPException(422, "Idempotency-Key must contain 8–160 letters, digits, colon, underscore or dash")
    return value


@router.post("/entries", status_code=201)
def create_entry(payload: EntryRequest, idempotency_key: str = Header(alias="Idempotency-Key"),
                 user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return public_run(WorkflowRepository(db).create(user_id, payload, request_key(idempotency_key)))


@router.get("/entries")
def list_entries(user_id: str = Depends(get_current_user), db: Client = Depends(get_db),
                 offset: int = Query(default=0, ge=0), limit: int = Query(default=30, ge=1, le=100)):
    return db.table("journal_entries").select("id,content,created_at").eq("user_id", user_id).order("created_at", desc=True).range(offset, offset+limit-1).execute().data or []


@router.get("/runs")
def list_runs(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    rows = db.table("workflow_runs").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(50).execute().data
    return [public_run(row) for row in rows or []]


@router.get("/entries/{entry_id}")
def get_entry(entry_id: UUID, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    rows = db.table("journal_entries").select("id,content,created_at").eq("id", str(entry_id)).eq("user_id", user_id).limit(1).execute().data
    if not rows:
        raise HTTPException(404, "Entry not found")
    return rows[0]


@router.get("/runs/{run_id}")
def get_run(run_id: UUID, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return public_run(WorkflowRepository(db).owned_run(user_id, run_id))


@router.post("/runs/{run_id}/decision", status_code=202)
def decide(run_id: UUID, payload: Decision, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    repo = WorkflowRepository(db)
    run = repo.owned_run(user_id, run_id)
    tasks = (run.get("proposal") or {}).get("tasks", [])
    if len(payload.selected_indices) != len(set(payload.selected_indices)) or any(i < 0 or i >= len(tasks) for i in payload.selected_indices):
        raise HTTPException(422, "Invalid task selection")
    return public_run(repo.resume(user_id, run_id, payload.version, payload.model_dump(), "awaiting_review"))


@router.post("/runs/{run_id}/clarification", status_code=202)
def clarify(run_id: UUID, payload: Clarification, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    repo = WorkflowRepository(db)
    run = repo.owned_run(user_id, run_id)
    return public_run(repo.resume(user_id, run_id, run["version"], payload.model_dump(), "awaiting_clarification"))


@router.patch("/runs/{run_id}/proposal")
def edit_proposal(run_id: UUID, payload: ProposalEdit, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    repo = WorkflowRepository(db)
    run = repo.owned_run(user_id, run_id)
    if run["status"] != "awaiting_review" or run["version"] != payload.version:
        raise HTTPException(409, "Proposal is no longer editable")
    if len(payload.proposal.tasks) != len(run["proposal"]["tasks"]):
        raise HTTPException(422, "Edit existing tasks; use selection to omit tasks")
    _, _, tasks = repo.context(run)
    try:
        validate_plan(payload.proposal, run["sources"], tasks)
    except ValueError:
        raise HTTPException(422, "Proposal must retain valid evidence, unique tasks and a bounded time budget") from None
    return public_run(repo.rpc("edit_proposal", {"p_owner": user_id, "p_run": str(run_id),
        "p_version": payload.version, "p_proposal": payload.proposal.model_dump()}))


@router.post("/runs/{run_id}/retry", status_code=202)
def retry_run(run_id: UUID, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    repo = WorkflowRepository(db)
    run = repo.owned_run(user_id, run_id)
    return public_run(repo.resume(user_id, run_id, run["version"], {}, "failed"))


@router.patch("/runs/{run_id}/sources", status_code=202)
def correct_sources(run_id: UUID, payload: SourceCorrection, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    repo = WorkflowRepository(db)
    run = repo.owned_run(user_id, run_id)
    old_ids = {source["source_id"] for source in run["sources"]}
    new_ids = [source.source_id for source in payload.sources]
    if set(new_ids) != old_ids or len(new_ids) != len(old_ids):
        raise HTTPException(422, "Correct existing excerpts without adding or removing sources")
    return public_run(repo.rpc("correct_sources", {"p_owner": user_id, "p_run": str(run_id),
        "p_version": payload.version, "p_sources": [source.model_dump() for source in payload.sources]}))


@router.post("/assets", status_code=201)
def upload_asset(file: UploadFile = File(...), user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    data = file.file.read(settings.MAX_UPLOAD_BYTES + 1)
    if not data or len(data) > settings.MAX_UPLOAD_BYTES:
        raise HTTPException(413, "File must be nonempty and within the configured upload limit")
    try:
        mime = validate_asset(data)
    except (ValueError, OSError):
        raise HTTPException(422, "Unsupported, disabled or invalid file") from None
    asset_id = str(uuid4())
    path = f"{user_id}/{asset_id}"
    db.table("users").upsert({"id": user_id}, ignore_duplicates=True).execute()
    storage = db.storage.from_(settings.STORAGE_BUCKET)
    # Stage metadata before storage I/O: even an interrupted upload stays discoverable.
    WorkflowRepository(db).rpc("register_asset",{"p_owner":user_id,"p_asset":{
        "id":asset_id,"filename":(file.filename or "attachment")[:255],
        "mime_type":mime,"storage_path":path,"size_bytes":len(data)}})
    storage.upload(path, data, file_options={"content-type": mime, "upsert": "false"})
    finalized=db.table("assets").update({"status":"ready"}).eq("id",asset_id).eq("user_id",user_id).execute().data
    if not finalized:
        raise HTTPException(409,"Upload could not be finalized")
    return {"id": asset_id, "filename": (file.filename or "attachment")[:255], "mime_type": mime}


@router.get("/assets/{asset_id}")
def preview_asset(asset_id: UUID, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    rows = db.table("assets").select("*").eq("id", str(asset_id)).eq("user_id", user_id).eq("status","ready").limit(1).execute().data
    if not rows:
        raise HTTPException(404, "Asset not found")
    data = db.storage.from_(settings.STORAGE_BUCKET).download(rows[0]["storage_path"])
    return StreamingResponse(io.BytesIO(data), media_type=rows[0]["mime_type"],
        headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "Content-Disposition": "attachment"})


@router.get("/assets")
def list_assets(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return db.table("assets").select("id,filename,mime_type,size_bytes,status,created_at").eq("user_id",user_id).order("created_at",desc=True).limit(100).execute().data or []


@router.delete("/assets/{asset_id}")
def forget_asset(asset_id: UUID, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    WorkflowRepository(db).rpc("forget_unused_asset",{"p_owner":user_id,"p_asset":str(asset_id)})
    return {"status":"deleted","storage_cleanup":"queued"}


@router.get("/memory")
def search_memory(q: str = Query(min_length=1, max_length=2000), user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    # Fast keyword search; worker uses hybrid vectors when inference is available.
    return WorkflowRepository(db).search(user_id, q)


@router.delete("/entries/{entry_id}")
def delete_entry(entry_id: UUID, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    rows = db.table("journal_entries").select("id").eq("id", str(entry_id)).eq("user_id", user_id).limit(1).execute().data
    if not rows:
        raise HTTPException(404, "Entry not found")
    WorkflowRepository(db).rpc("forget_entry", {"p_owner": user_id, "p_entry": str(entry_id)})
    return {"status": "deleted", "retention_cleanup": "queued"}


@router.get("/capabilities")
def capabilities(user_id: str = Depends(get_current_user)):
    from importlib.util import find_spec
    return {"audio": settings.ENABLE_AUDIO and find_spec("faster_whisper") is not None,
            "scanned_pdf_ocr": settings.ENABLE_DOCLING and find_spec("docling") is not None,
            "max_upload_bytes": settings.MAX_UPLOAD_BYTES, "max_assets": 5}


@router.get("/export")
def export_data(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    # Explicit capped export; pagination must be added before accounts exceed these caps.
    result = {}
    for table in ("users", "journal_entries", "tasks", "objectives", "user_media", "automation_rules"):
        query = db.table(table).select("*").eq("id" if table == "users" else "user_id", user_id)
        result[table] = query.limit(1000).execute().data or []
    return {"data": result, "per_table_limit": 1000}


@router.get("/automations")
def list_automations(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return db.table("automation_rules").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(100).execute().data or []


@router.post("/automations", status_code=201)
def create_automation(payload: AutomationRequest, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return WorkflowRepository(db).rpc("create_automation",{"p_owner":user_id,"p_rule":payload.model_dump()})


@router.patch("/automations/{rule_id}")
def toggle_automation(rule_id: UUID, payload: AutomationToggle, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    result = db.table("automation_rules").select("id").eq("id", str(rule_id)).eq("user_id", user_id).limit(1).execute().data
    if not result:
        raise HTTPException(404, "Automation not found")
    return WorkflowRepository(db).rpc("set_automation_enabled",{"p_owner":user_id,"p_rule":str(rule_id),"p_enabled":payload.enabled})


@router.get("/automation-events")
def automation_events(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return db.table("automation_events").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(100).execute().data or []
