from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from supabase import Client
from app.core.db import get_db
from app.core.security import get_current_user
from app.services.model_provider import get_model_provider
from app.services.assistant import ask
from app.services.workflow_repository import WorkflowRepository

router = APIRouter()


class Turn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    question: str = Field(min_length=1, max_length=2000)
    answer: str = Field(min_length=1, max_length=6000)


class Question(BaseModel):
    model_config = ConfigDict(extra="forbid")
    question: str = Field(min_length=1, max_length=2000)
    history: list[Turn] = Field(default_factory=list, max_length=4)

    @field_validator("question")
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError("Question is required")
        return value.strip()


@router.post("")
def answer(payload: Question, owner: str = Depends(get_current_user), db: Client = Depends(get_db), provider=Depends(get_model_provider)):
    WorkflowRepository(db).rpc("reserve_inline_model_call", {"p_owner": owner})
    try:
        return ask(db, provider, owner, payload.question, [turn.model_dump() for turn in payload.history])
    except HTTPException:
        raise
    except Exception as exc:
        if getattr(exc, "code", None) == 429:
            raise HTTPException(429, "The AI provider quota is reached. Please try later or check the configured provider plan.") from None
        raise HTTPException(503, "The assistant could not produce a supported answer. Please retry.") from None
