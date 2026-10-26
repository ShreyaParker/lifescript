# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    import asyncio
    from app.core.config import settings
    from supabase import create_client, Client
    import json
    
    async def main():
        supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        
        try:
            archetype_data = {
                "alignment": "Granular Milestone Metrics",
                "bottleneck": "High-Level Vision Alignment",
                "driver": "Gamified XP Progression"
            }
            
            # we don't have the exact user id, so let's get the user ID first
            users = supabase.auth.admin.list_users()
            user_id = users[0].id
            
            print("Upserting for user", user_id)
            result = supabase.table("users").upsert({
                "id": user_id,
                "email": f"{user_id}@placeholder.com",
                "onboarding_complete": True,
                "archetype_data": archetype_data
            }).execute()
            
            print("Success:", result)
        except Exception as e:
            print("Error during upsert:", e)
    
    if __name__ == "__main__":
        asyncio.run(main())
