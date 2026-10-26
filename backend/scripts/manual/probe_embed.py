# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    import asyncio
    from app.core.config import settings
    from google import genai
    from google.genai import types
    
    async def test_embed():
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        try:
            response = client.models.embed_content(
                model="gemini-embedding-2",
                contents="hello",
                config=types.EmbedContentConfig(output_dimensionality=768)
            )
            print("SUCCESS EMBED:", len(response.embeddings[0].values))
        except Exception as e:
            print("ERROR EMBED:", str(e))
    
    asyncio.run(test_embed())
