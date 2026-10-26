from pydantic import BaseModel, Field
from typing import List, Optional

class ProfileProgress(BaseModel):
    occupation: Optional[str] = Field(None, description="User's professional context or status")
    interests: List[str] = Field(default_factory=list, description="Extracted passions or areas of focus")
    macro_goals: List[str] = Field(default_factory=list, description="Long-term life objectives")
    friction_points: List[str] = Field(default_factory=list, description="Struggles or daily bottlenecks")

class OnboardingSessionSchema(BaseModel):
    extracted_profile: ProfileProgress
    next_question: Optional[str] = Field(description="The next logical question. Return null if profile is comprehensive.")
    is_complete: bool = Field(default=False, description="Set to true when core profile points are mapped.")
