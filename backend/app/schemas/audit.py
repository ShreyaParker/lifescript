from pydantic import BaseModel, Field
from typing import Optional

class Adjustment(BaseModel):
    action: str = Field(description="Action to take, e.g., 'Scale Back'")
    detail: str = Field(description="Details of the action, e.g., 'Reduce milestone target'")

class AuditResultSchema(BaseModel):
    pattern_detected: bool = Field(description="Set to true if a specific behavioral trend is observed over the entries.")
    coaching_message: str = Field(description="Empathetic, non-clinical strategy suggestion focused on scheduling optimization.")
    suggested_adjustment: Optional[Adjustment] = Field(
        None, 
        description="Actionable structural change if needed."
    )
