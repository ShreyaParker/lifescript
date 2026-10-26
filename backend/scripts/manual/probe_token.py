# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    import asyncio
    from app.core.config import settings
    from supabase import create_client, Client
    
    async def main():
        supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        
        # Check if we can get user with an invalid token
        try:
            res = supabase.auth.get_user("invalid_jwt")
            print("Success:", res)
        except Exception as e:
            print("Exception:", e)
    
    if __name__ == "__main__":
        asyncio.run(main())
