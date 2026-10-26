from google import genai
from google.genai import types
from app.schemas.task import ScriptwriterOutputSchema

class ScriptwriterAgent:
    def __init__(self, api_key: str):
        self.client = genai.Client(api_key=api_key)
        self.model_name = "gemini-2.5-flash"

    async def generate_script_tasks(self, journal_content: str, macro_goals: list[str]) -> ScriptwriterOutputSchema:
        system_instruction = f"""
        You are the 'Scriptwriter Agent' inside lifescript. Your objective is to read a user's daily reflection and break down their long-term intentions into micro-actions for tomorrow.
        
        USER'S MACRO LIFE GOALS:
        {", ".join(macro_goals) if macro_goals else "Continuous growth and self-improvement."}

        CRITICAL OPERATING RULES:
        1. Deconstruct large goals into tiny steps (e.g., do not say 'Build Flutter App'; say 'Code the task card layout view').
        2. Detect entity mentions: If they watched a movie or read a book, tie a reflective or continuation task to it.
        3. Be an architect, not a boss. Keep the tasks highly manageable to maintain momentum.
        """

        response = self.client.models.generate_content(
            model=self.model_name,
            contents=f"Today's Journal Entry: {journal_content}",
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                response_mime_type="application/json",
                response_schema=ScriptwriterOutputSchema,
                temperature=0.5, # Slightly creative but highly structural
            ),
        )

        return ScriptwriterOutputSchema.model_validate_json(response.text)
