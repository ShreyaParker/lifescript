# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    import asyncio
    from app.core.config import settings
    from app.agents.auditor import AuditorAgent
    
    async def test_audit():
        a = AuditorAgent(settings.GEMINI_API_KEY)
        try:
            res = await a.analyze_weekly_alignment(["log1", "log2", "log3"], ["goal1"])
            print("SUCCESS AUDIT:", res)
        except Exception as e:
            print("ERROR AUDIT:", str(e))
    
    asyncio.run(test_audit())
