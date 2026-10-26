from datetime import date as Date, datetime, time, timedelta, timezone
from typing import Literal
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator
from supabase import Client
from app.core.db import get_db
from app.core.security import get_current_user

router = APIRouter()

class TaskToggleRequest(BaseModel):
    is_completed: bool

@router.get("")
def list_tasks(user_id: str = Depends(get_current_user), db: Client = Depends(get_db),
               status: Literal["pending", "completed"] | None = None,
               limit: int = Query(default=100, ge=1, le=200), offset: int = Query(default=0, ge=0)):
    query = db.table("tasks").select("*").eq("user_id", user_id)
    if status:
        query = query.eq("status", status)
    return query.order("created_at", desc=True).range(offset, offset + limit - 1).execute().data or []

@router.get("/archive")
def get_archived_tasks(date: Date, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    start = datetime.combine(date, time.min, tzinfo=timezone.utc)
    return (db.table("tasks").select("*").eq("user_id", user_id)
            .gte("created_at", start.isoformat()).lt("created_at", (start + timedelta(days=1)).isoformat())
            .order("created_at").limit(200).execute().data or [])

@router.patch("/{task_id}/toggle")
def toggle_task_status(task_id: UUID, payload: TaskToggleRequest, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    status = "completed" if payload.is_completed else "pending"
    response = db.table("tasks").update({"status": status}).eq("id", str(task_id)).eq("user_id", user_id).execute()
    if not response.data:
        raise HTTPException(404, "Task not found")
    return {"status": "success", "task_id": str(task_id), "new_status": status}


class TaskEdit(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str = Field(min_length=1, max_length=255)
    description: str = Field(default="", max_length=4000)
    objective_id: UUID | None = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, value):
        if not value.strip():
            raise ValueError("Title is required")
        return value.strip()


@router.patch("/{task_id}")
def edit_task(task_id: UUID, payload: TaskEdit, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    if payload.objective_id:
        from app.routers.objectives import owned
        owned(db, user_id, payload.objective_id)
    result = db.table("tasks").update(payload.model_dump(mode="json")).eq("id", str(task_id)).eq("user_id", user_id).execute().data
    if not result:
        raise HTTPException(404, "Task not found")
    return result[0]
