from datetime import datetime, timedelta, timezone
from uuid import uuid4
from fastapi import APIRouter, Depends, Header
from pydantic import BaseModel, Field
from supabase import Client
from app.core.db import get_db
from app.core.security import get_current_user
from app.schemas.audit import AuditResultSchema
from app.schemas.workflow import EntryRequest
from app.services.workflow_repository import WorkflowRepository
from app.routers.workflows import request_key
from app.services.progress_service import weekly_counts

router = APIRouter()

class JournalSubmitRequest(BaseModel):
    content: str = Field(min_length=1, max_length=20000)

@router.post("/submit", status_code=202)
def submit_daily_journal(payload: JournalSubmitRequest, user_id: str = Depends(get_current_user),
                         db: Client = Depends(get_db), idempotency_key: str | None = Header(default=None)):
    run = WorkflowRepository(db).create(user_id, EntryRequest(content=payload.content),
                                        request_key(idempotency_key or str(uuid4())))
    return {"status": "queued", "entry_id": run["entry_id"], "run_id": run["id"],
            "coaching_insight": "Your reflection is saved. Suggestions will be ready for review after processing.",
            "generated_tasks": []}

@router.get("/audit", response_model=AuditResultSchema)
def generate_user_script_audit(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    counts=weekly_counts(db,user_id)
    if not counts["reflections"]:
        return AuditResultSchema(pattern_detected=False, coaching_message="No reflections saved in the last seven days.")
    return AuditResultSchema(pattern_detected=False, coaching_message=(
        f"In the last seven days you saved {counts['reflections']} reflections. "
        f"{counts['tasks_currently_completed']} of {counts['tasks_created']} tasks created in that period are currently completed. "
        "Choose a manageable next step and review your pending work."))
