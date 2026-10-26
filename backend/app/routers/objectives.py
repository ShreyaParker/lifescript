"""Owner-scoped goal/project organization; no model may write through these routes."""
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from supabase import Client

from app.core.db import get_db
from app.core.security import get_current_user

router = APIRouter()


class ObjectiveCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: UUID
    title: str = Field(min_length=1, max_length=255)
    kind: Literal["goal", "project"]
    parent_id: UUID | None = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, value):
        if not value.strip():
            raise ValueError("Title is required")
        return value.strip()

    @model_validator(mode="after")
    def hierarchy(self):
        if self.parent_id and (self.kind != "project" or self.parent_id == self.id):
            raise ValueError("Only a project can belong to a separate goal")
        return self


class ObjectiveStatus(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["active", "completed"] | None = None
    title: str | None = Field(default=None, min_length=1, max_length=255)

    @model_validator(mode="after")
    def valid_update(self):
        if not self.model_fields_set or any(getattr(self, k) is None for k in self.model_fields_set):
            raise ValueError("Supply a title or status")
        if self.title is not None:
            if not self.title.strip():
                raise ValueError("Title is required")
            self.title = self.title.strip()
        return self


def owned(db, owner, objective_id):
    rows = db.table("objectives").select("*").eq("user_id", owner).eq("id", str(objective_id)).limit(1).execute().data
    if not rows:
        raise HTTPException(404, "Goal or project not found")
    return rows[0]


@router.get("")
def list_objectives(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return db.table("objectives").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(200).execute().data or []


@router.post("", status_code=201)
def create_objective(payload: ObjectiveCreate, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    data = payload.model_dump(mode="json")
    existing = db.table("objectives").select("*").eq("id", str(payload.id)).eq("user_id", user_id).limit(1).execute().data
    if existing:
        if any(existing[0].get(k) != v for k, v in data.items()):
            raise HTTPException(409, "Operation ID already used for different content")
        return existing[0]
    if payload.parent_id and owned(db, user_id, payload.parent_id)["kind"] != "goal":
        raise HTTPException(422, "A project must belong to a goal")
    db.table("users").upsert({"id": user_id}, ignore_duplicates=True).execute()
    # Stable client-generated UUID prevents duplicate creation after transport retries.
    db.table("objectives").upsert({**data, "user_id": user_id}, ignore_duplicates=True).execute()
    result = owned(db, user_id, payload.id)
    if any(result.get(k) != v for k, v in data.items()):
        raise HTTPException(409, "Operation ID already used for different content")
    return result


@router.patch("/{objective_id}")
def set_status(objective_id: UUID, payload: ObjectiveStatus, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    owned(db, user_id, objective_id)
    return db.table("objectives").update(payload.model_dump(exclude_unset=True)).eq("id", str(objective_id)).eq("user_id", user_id).execute().data[0]
