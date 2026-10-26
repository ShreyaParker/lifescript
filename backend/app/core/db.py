import httpx
from app.core.tls import tls_context
from functools import lru_cache
from fastapi import HTTPException
from supabase import Client, create_client
from supabase.lib.client_options import SyncClientOptions
from app.core.config import settings

@lru_cache
def get_db() -> Client:
    """Lazy initialization: imports and isolated tests do not need credentials."""
    if not settings.SUPABASE_URL or not settings.SUPABASE_KEY:
        raise HTTPException(503, "Database is not configured")
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY,
        options=SyncClientOptions(auto_refresh_token=False,persist_session=False,
            postgrest_client_timeout=15,storage_client_timeout=30,
            httpx_client=httpx.Client(verify=tls_context(), timeout=httpx.Timeout(30, connect=15))))
