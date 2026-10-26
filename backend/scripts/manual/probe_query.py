# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    import asyncio
    from app.core.config import settings
    from app.core.db import get_db
    
    def test_db():
        db = get_db()
        try:
            response = db.table("journal_entries").select("content").limit(1).execute()
            print("SUCCESS:", response)
        except Exception as e:
            print("ERROR:", str(e))
    
    test_db()
