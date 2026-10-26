from typing import Literal
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field, field_validator
from supabase import Client
from app.core.db import get_db
from app.core.security import get_current_user

router = APIRouter()

class UpdateGoalsRequest(BaseModel):
    goals: list[str] = Field(max_length=20)
    @field_validator("goals")
    @classmethod
    def valid_goals(cls, value):
        if any(not goal.strip() or len(goal) > 255 for goal in value):
            raise ValueError("Goals must contain 1-255 characters")
        return list(dict.fromkeys(goal.strip() for goal in value))

class AddMediaRequest(BaseModel):
    media_type: Literal["book", "movie", "hobby"]
    title: str = Field(min_length=1, max_length=255)
    current_status: Literal["reading", "watching", "in_progress", "completed"] = "completed"

@router.get("/")
def get_profile(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    rows = db.table("users").select("archetype_data,macro_goals,primary_north_star,onboarding_complete").eq("id", user_id).limit(1).execute().data
    media = db.table("user_media").select("*").eq("user_id", user_id).order("updated_at", desc=True).limit(200).execute().data
    return {"profile": rows[0] if rows else {}, "media": media or []}

@router.post("/goals")
def update_goals(payload: UpdateGoalsRequest, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    db.table("users").upsert({"id": user_id, "macro_goals": payload.goals}).execute()
    return {"status": "success"}

@router.post("/media")
def add_media(payload: AddMediaRequest, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    result = db.table("user_media").insert({"user_id": user_id, **payload.model_dump()}).execute()
    return {"status": "success", "media": result.data}
