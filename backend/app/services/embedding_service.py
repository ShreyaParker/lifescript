from google import genai
from google.genai import types

class EmbeddingService:
    def __init__(self, api_key: str):
        self.client = genai.Client(api_key=api_key)
        # Using Google's industry-standard compact embedding model
        self.model_name = "gemini-embedding-2" 

    async def generate_embedding(self, text: str) -> list[float]:
        """
        Converts unstructured text into a 768-dimensional vector float list
        """
        try:
            response = self.client.models.embed_content(
                model=self.model_name,
                contents=text,
                config=types.EmbedContentConfig(output_dimensionality=768)
            )
            # Extract the raw float array from the embedding response object
            return response.embeddings[0].values
        except Exception as e:
            raise RuntimeError(f"Failed to generate vector embedding: {str(e)}")
