# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    import asyncio
    from app.core.config import settings
    from app.services.embedding_service import EmbeddingService
    from app.agents.scriptwriter import ScriptwriterAgent
    
    async def test():
        content = "Today I spent about 2 hours watching a long YouTube crash course on Neural Networks..."
        try:
            embedding_engine = EmbeddingService(api_key=settings.GEMINI_API_KEY)
            vector_embedding = await embedding_engine.generate_embedding(content)
            print("EMBEDDING SUCCESS, length:", len(vector_embedding))
        except Exception as e:
            print("EMBEDDING ERROR:", str(e))
            return
    
        try:
            mock_macro_goals = ["Master AI engineering", "Maintain clear physical health metrics"]
            writer_agent = ScriptwriterAgent(api_key=settings.GEMINI_API_KEY)
            script_blueprint = await writer_agent.generate_script_tasks(content, mock_macro_goals)
            print("SCRIPTWRITER SUCCESS:", script_blueprint)
        except Exception as e:
            print("SCRIPTWRITER ERROR:", str(e))
            return
    
    asyncio.run(test())
