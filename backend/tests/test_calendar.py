import hashlib
import httpx
import pytest
from cryptography.fernet import Fernet

from app.core.config import settings
from app.routers.calendar import CalendarDraft
from app.services.calendar_service import cipher, encrypt_token, ensure_event


def test_calendar_event_identity_prevents_duplicate_external_write():
    action={"id":"action-1","payload":{"summary":"Study","start":"2026-10-22T10:00:00Z","end":"2026-10-22T11:00:00Z"}}
    stored={}; calls=[]
    def handler(request):
        calls.append(request.method)
        if request.method=="GET":
            return httpx.Response(200,json=stored) if stored else httpx.Response(404,json={})
        import json
        stored.update(json.loads(request.content))
        return httpx.Response(200,json=stored)
    with httpx.Client(transport=httpx.MockTransport(handler)) as client:
        first=ensure_event(client,"fake-token",action)
        second=ensure_event(client,"fake-token",action)
    assert first==second==hashlib.sha256(b"action-1").hexdigest()
    assert calls==["GET","POST","GET"]


def test_calendar_timeout_is_reconciled_by_read():
    action={"id":"action-2","payload":{"summary":"Study","start":"2026-10-22T10:00:00Z","end":"2026-10-22T11:00:00Z"}}
    stored={}
    def handler(request):
        if request.method=="GET":
            return httpx.Response(200,json=stored) if stored else httpx.Response(404,json={})
        import json
        stored.update(json.loads(request.content))
        raise httpx.ReadTimeout("Response lost after external success")
    with httpx.Client(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(httpx.ReadTimeout): ensure_event(client,"fake",action)
        assert ensure_event(client,"fake",action)==stored["id"]


def test_calendar_tokens_are_encrypted(monkeypatch):
    monkeypatch.setattr(settings,"GOOGLE_CALENDAR_CLIENT_ID","test")
    monkeypatch.setattr(settings,"GOOGLE_CALENDAR_CLIENT_SECRET","test")
    monkeypatch.setattr(settings,"TOKEN_ENCRYPTION_KEY",Fernet.generate_key().decode())
    value=encrypt_token({"refresh_token":"private-test-value"})
    assert "private-test-value" not in value
    assert "private-test-value" in cipher().decrypt(value.encode()).decode()


def test_calendar_requires_offset_and_positive_bounded_duration():
    with pytest.raises(ValueError): CalendarDraft(summary="Study",start="2026-10-22T10:00:00",end="2026-10-22T11:00:00")
    with pytest.raises(ValueError): CalendarDraft(summary="Study",start="2026-10-22T11:00:00Z",end="2026-10-22T10:00:00Z")
