# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    import asyncio
    from app.core.config import settings
    from app.core.db import get_db
    
    def test_db_insert():
        db = get_db()
        try:
            # Let's see if we have ANY user in auth.users or public.users
            users_res = db.table("users").select("id").limit(1).execute()
            if not users_res.data:
                print("No users in public.users")
                return
                
            user_id = users_res.data[0]["id"]
            print("Found user:", user_id)
            
            # Try insert dummy journal entry
            db_payload = {
                "user_id": user_id,
                "content": "Test",
                "embedding": [0.0]*768
            }
            res = db.table("journal_entries").insert(db_payload).execute()
            print("INSERT SUCCESS:", res.data)
            
        except Exception as e:
            print("INSERT ERROR:", str(e))
    
    test_db_insert()
