import json
from google import genai
from google.genai import types
from app.core.config import settings
from app.schemas.onboarding import OnboardingSessionSchema

class OnboardingService:
    def __init__(self, api_key: str):
        # Initialize the modern Google GenAI Client using the user's injected BYOK key
        self.client = genai.Client(api_key=api_key)
        self.model_name = "gemini-2.5-flash" # High-speed, perfect for interactive chat

    async def process_chat_turn(self, conversation_history: list[dict], current_user_reply: str) -> OnboardingSessionSchema:
        # Construct a precise system prompt instructing Gemini on its role
        system_instruction = """
        You are the onboarding guide for 'lifescript', an empathetic and therapeutic life operating system.
        Your goal is to converse with the user to discover:
        1. Their current occupation/context.
        2. Top core interests.
        3. 1-2 major macro life goals.
        4. Daily friction points or bottlenecks holding them back.

        BEHAVIOR:
        - Be warm, concise, and deeply supportive. Never lecture.
        - Ask exactly ONE clear question at a time based on what is missing.
        - If the user provides a brief answer, extract it into the profile and move to the next area.
        - When all major categories have at least some basic information, or after 4 total turns, set 'is_complete' to true and 'next_question' to null.
        """

        # Append the latest user message to the historical exchange
        full_messages = []
        for turn in conversation_history:
            role = "user" if turn["role"] == "user" else "model"
            full_messages.append(types.Content(role=role, parts=[types.Part.from_text(text=turn["text"])]))
        
        full_messages.append(types.Content(role="user", parts=[types.Part.from_text(text=current_user_reply)]))

        # Call Gemini requesting structured JSON enforcement matching our Pydantic schema
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=full_messages,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                response_mime_type="application/json",
                response_schema=OnboardingSessionSchema,
                temperature=0.4, # Kept low for predictable, highly structural parsing
            ),
        )

        # Parse the guaranteed valid JSON payload directly into the schema representation
        return OnboardingSessionSchema.model_validate_json(response.text)
