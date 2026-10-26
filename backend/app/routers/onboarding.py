from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field
from supabase import Client
from app.core.db import get_db
from app.core.security import get_current_user

router = APIRouter()

class DeeperProfileRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    inner_landscape: str = Field(min_length=1, max_length=1000)
    subconscious_rhythm: str = Field(min_length=1, max_length=1000)
    intellectual_footprint: str = Field(min_length=1, max_length=1000)
    core_north_star: str = Field(min_length=1, max_length=255)

@router.post("/setup")
def setup_deeper_profile(payload: DeeperProfileRequest, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    db.table("users").upsert({
        "id": user_id, "onboarding_complete": True,
        "primary_north_star": payload.core_north_star,
        "macro_goals": [payload.core_north_star], "archetype_data": payload.model_dump(),
    }).execute()
    return {"status": "success", "message": "Profile saved."}
