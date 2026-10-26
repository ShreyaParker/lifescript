from pydantic import BaseModel, Field
from typing import List

class ExtractedTask(BaseModel):
    title: str = Field(description="Concise, actionable task title (e.g., 'Read 5 pages of Python book')")
    description: str = Field(description="Context on why this task helps their macro script execution.")
    xp_value: int = Field(default=20, description="XP reward based on cognitive load (scale: 10 to 50)")

class ScriptwriterOutputSchema(BaseModel):
    tasks: List[ExtractedTask]
    coaching_insight: str = Field(description="A brief, 1-2 sentence warm reflection on today's progress.")
