from typing import Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, field_validator

class EntryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    content: str = Field(min_length=1, max_length=20000)
    asset_ids: list[UUID] = Field(default_factory=list, max_length=5)
    timezone: str = "Asia/Kolkata"

    @field_validator("timezone")
    @classmethod
    def timezone_exists(cls, value):
        from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError("Unknown IANA timezone") from exc
        return value

class ProposedTask(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=2000)
    evidence: str = Field(min_length=1, max_length=1000)
    source_id: str = Field(min_length=1, max_length=100)
    duration_minutes: int = Field(default=20, ge=5, le=240)
    xp_value: int = Field(default=20, ge=10, le=50)

class Understanding(BaseModel):
    intent: Literal["action", "reflection", "ambiguous"] = "action"
    facts: list[str] = Field(default_factory=list, max_length=20)
    questions: list[str] = Field(default_factory=list, max_length=3)

class Plan(BaseModel):
    tasks: list[ProposedTask] = Field(default_factory=list, max_length=5)
    coaching_insight: str = Field(min_length=1, max_length=2000)

class Decision(BaseModel):
    model_config = ConfigDict(extra="forbid")
    decision: Literal["approve", "reject"]
    selected_indices: list[int] = Field(default_factory=list, max_length=5)
    version: int = Field(ge=1)

class ProposalEdit(BaseModel):
    version: int = Field(ge=1)
    proposal: Plan

class SourceExcerpt(BaseModel):
    source_id: str = Field(min_length=1, max_length=100)
    content: str = Field(min_length=1, max_length=30000)

class SourceCorrection(BaseModel):
    version: int = Field(ge=1)
    sources: list[SourceExcerpt] = Field(min_length=1, max_length=100)

    @field_validator("sources")
    @classmethod
    def bounded_sources(cls, value):
        if sum(len(source.content) for source in value)>30000:
            raise ValueError("Corrected source context exceeds limit")
        return value

class Clarification(BaseModel):
    answer: str = Field(min_length=1, max_length=4000)

class AutomationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=1, max_length=100)
    kind: Literal["daily_plan", "weekly_review", "reminder"]
    instruction: str = Field(min_length=1, max_length=2000)
    interval_hours: int = Field(default=24, ge=1, le=168)
    enabled: bool = True

class AutomationToggle(BaseModel):
    enabled: bool
