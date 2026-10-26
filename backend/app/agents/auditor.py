from google import genai
from google.genai import types
from app.schemas.audit import AuditResultSchema

class AuditorAgent:
    def __init__(self, api_key: str):
        self.client = genai.Client(api_key=api_key)
        self.model_name = "gemini-2.5-flash"

    async def analyze_weekly_alignment(self, journal_texts: list[str], macro_goals: list[str]) -> AuditResultSchema:
        # Construct a strict structural behavioral evaluation prompt
        system_instruction = f"""
        You are the 'Auditor Agent' inside lifescript. Your role is to look at a user's collection of daily logs from the past week and evaluate their alignment with their macro ambitions.
        
        USER'S STRATEGIC GOALS:
        {", ".join(macro_goals)}

        CRITICAL BEHAVIORAL BUNDLES:
        1. Identify trends: Look for recurring friction points (e.g., exhaustion on Wednesdays, constant social media distractions).
        2. Keep it therapeutic and objective: Avoid diagnostic or clinical mental health labels. Frame everything as 'energy allocation' or 'scheduling optimization'.
        3. If they are executing perfectly, set pattern_detected to false and congratulate their momentum in the coaching_message.
        """

        # Format the historical logs chronologically for the context block
        formatted_history = "\n---\n".join([f"Day Entry: {text}" for text in journal_texts])
        user_prompt = f"Review the following chronological logs for macro alignment:\n\n{formatted_history}"

        response = self.client.models.generate_content(
            model=self.model_name,
            contents=user_prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                response_mime_type="application/json",
                response_schema=AuditResultSchema,
                temperature=0.3, # Kept tight for analytical accuracy rather than high creativity
            ),
        )

        return AuditResultSchema.model_validate_json(response.text)
