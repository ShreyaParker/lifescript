from google import genai
from google.genai import types

class ResonanceAgent:
    def __init__(self, api_key: str):
        self.client = genai.Client(api_key=api_key)

    async def analyze_flashback_portal(self, image_bytes: bytes, image_metadata: dict) -> dict:
        system_instruction = """
        Analyze the image's visual framework (lighting vectors, color temperature, composition) alongside its timestamp metadata.
        Output an empathetic historical analysis tying the image properties to deeper psychological themes of energy allocation or autonomy.
        """
        
        image_part = types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg")
        prompt = f"Image taken on: {image_metadata.get('date')}. Process emotional sentiment analysis."

        response = self.client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[image_part, prompt],
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.3
            )
        )
        return {"historical_entry": response.text}
