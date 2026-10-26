import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse
from pydantic import AwareDatetime, BaseModel, Field, model_validator
from supabase import Client

from app.core.config import settings
from app.core.tls import tls_context
from app.core.db import get_db
from app.core.security import get_current_user
from app.services.calendar_service import cipher, encrypt_token
from app.services.workflow_repository import WorkflowRepository

router = APIRouter()


class CalendarDraft(BaseModel):
    summary: str = Field(min_length=1, max_length=200)
    start: AwareDatetime
    end: AwareDatetime

    @model_validator(mode="after")
    def valid_interval(self):
        if not timedelta(0) < self.end - self.start <= timedelta(days=1):
            raise ValueError("Event must last between zero and 24 hours")
        return self


class CalendarDecision(BaseModel):
    approve: bool


@router.get("/connection")
def connection(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    rows = db.table("calendar_connections").select("user_id").eq("user_id", user_id).limit(1).execute().data
    return {"connected": bool(rows), "configured": bool(settings.GOOGLE_CALENDAR_CLIENT_ID and settings.GOOGLE_CALENDAR_CLIENT_SECRET and settings.TOKEN_ENCRYPTION_KEY)}


@router.post("/connect")
def connect(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    cipher()
    state = secrets.token_urlsafe(32)
    db.table("users").upsert({"id": user_id}, ignore_duplicates=True).execute()
    db.table("calendar_oauth_states").insert({"state_hash": hashlib.sha256(state.encode()).hexdigest(),
        "user_id": user_id, "expires_at": (datetime.now(timezone.utc)+timedelta(minutes=10)).isoformat()}).execute()
    return {"authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?" + urlencode({
        "client_id": settings.GOOGLE_CALENDAR_CLIENT_ID, "redirect_uri": settings.GOOGLE_CALENDAR_REDIRECT_URL,
        "response_type": "code", "scope": "https://www.googleapis.com/auth/calendar.events.owned",
        "access_type": "offline", "prompt": "consent", "state": state,
    })}


@router.get("/callback", response_class=HTMLResponse)
def callback(state: str = Query(min_length=20, max_length=200), code: str = Query(min_length=1, max_length=4096), db: Client = Depends(get_db)):
    cipher()
    # Atomic consume: callback state is single-use, time-limited, and owner-bound.
    rows = (db.table("calendar_oauth_states").delete().eq("state_hash", hashlib.sha256(state.encode()).hexdigest())
            .gte("expires_at", datetime.now(timezone.utc).isoformat()).execute().data)
    if not rows:
        raise HTTPException(400, "Connection request expired or was already used")
    with httpx.Client(verify=tls_context(), timeout=30) as client:
        response = client.post("https://oauth2.googleapis.com/token", data={
            "client_id": settings.GOOGLE_CALENDAR_CLIENT_ID, "client_secret": settings.GOOGLE_CALENDAR_CLIENT_SECRET,
            "code": code, "redirect_uri": settings.GOOGLE_CALENDAR_REDIRECT_URL, "grant_type": "authorization_code",
        })
        response.raise_for_status()
        token = response.json()
    if not token.get("refresh_token"):
        raise HTTPException(400, "Offline calendar permission was not granted. Connect again.")
    db.table("calendar_connections").upsert({"user_id": rows[0]["user_id"],
        "token_ciphertext": encrypt_token({"refresh_token": token["refresh_token"]})}).execute()
    return "<html><body><p>Calendar connected. Return to LifeScript and refresh connections.</p></body></html>"


@router.delete("/connection")
def disconnect(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    db.table("calendar_connections").delete().eq("user_id", user_id).execute()
    db.table("calendar_actions").update({"status": "rejected"}).eq("user_id", user_id).eq("status", "approved").execute()
    # Removes locally stored credentials; provider-side grant can also be revoked in Google account settings.
    return {"status": "disconnected"}


@router.get("/actions")
def actions(user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return db.table("calendar_actions").select("id,payload,status,remote_id,error_code,created_at").eq("user_id", user_id).order("created_at", desc=True).limit(100).execute().data or []


@router.post("/actions", status_code=201)
def propose(payload: CalendarDraft, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    db.table("users").upsert({"id": user_id}, ignore_duplicates=True).execute()
    return db.table("calendar_actions").insert({"user_id": user_id, "payload": payload.model_dump(mode="json")}).execute().data[0]


@router.post("/actions/{action_id}/decision")
def decide(action_id: UUID, payload: CalendarDecision, user_id: str = Depends(get_current_user), db: Client = Depends(get_db)):
    return WorkflowRepository(db).rpc("decide_calendar_action", {"p_owner": user_id, "p_action": str(action_id), "p_approve": payload.approve})
