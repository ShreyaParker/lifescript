import httpx
from supabase import create_client

from app.core import db


def test_database_client_initializes_with_sync_sdk_options(monkeypatch):
    """Exercise SDK construction without credentials or network requests."""
    requests = []

    def reject_network(request):
        requests.append(request)
        raise AssertionError("Client initialization must not make requests")

    with httpx.Client(transport=httpx.MockTransport(reject_network)) as transport:
        def construct(url, key, options):
            assert options.auto_refresh_token is False
            assert options.persist_session is False
            assert options.postgrest_client_timeout == 15
            assert options.storage_client_timeout == 30
            assert options.httpx_client is not None
            options.httpx_client.close()
            options.httpx_client = transport
            return create_client(url, key, options=options)

        monkeypatch.setattr(db.settings, "SUPABASE_URL", "https://example.supabase.co")
        monkeypatch.setattr(db.settings, "SUPABASE_KEY", "test-only-key")
        monkeypatch.setattr(db, "create_client", construct)
        db.get_db.cache_clear()
        try:
            client = db.get_db()
            assert client.auth is not None
            assert client.table("profiles") is not None
            assert db.get_db() is client
            assert requests == []
        finally:
            db.get_db.cache_clear()


def test_platform_tls_requires_verified_certificates():
    import ssl
    from app.core.tls import tls_context
    context = tls_context()
    assert context.verify_mode == ssl.CERT_REQUIRED
    assert context.check_hostname is True
    assert tls_context() is context
