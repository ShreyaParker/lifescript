"""Google Calendar adapter. Calls only execute for separately approved actions."""
import hashlib
import json
from datetime import datetime, timedelta, timezone

import httpx
from cryptography.fernet import Fernet
from fastapi import HTTPException

from app.core.config import settings
from app.core.tls import tls_context

API = "https://www.googleapis.com/calendar/v3/calendars/primary/events"


def cipher():
    if not all((settings.GOOGLE_CALENDAR_CLIENT_ID, settings.GOOGLE_CALENDAR_CLIENT_SECRET, settings.TOKEN_ENCRYPTION_KEY)):
        raise HTTPException(503, "Calendar connection is not configured")
    try:
        return Fernet(settings.TOKEN_ENCRYPTION_KEY.encode())
    except ValueError:
        raise HTTPException(503, "Calendar connection is not configured") from None


def encrypt_token(data):
    return cipher().encrypt(json.dumps(data).encode()).decode()


def access_token(db, owner, client):
    connections = db.table("calendar_connections").select("token_ciphertext").eq("user_id", owner).limit(1).execute().data
    if not connections:
        raise ValueError("calendar_not_connected")
    stored = json.loads(cipher().decrypt(connections[0]["token_ciphertext"].encode()))
    response = client.post("https://oauth2.googleapis.com/token", data={
        "client_id": settings.GOOGLE_CALENDAR_CLIENT_ID, "client_secret": settings.GOOGLE_CALENDAR_CLIENT_SECRET,
        "refresh_token": stored["refresh_token"], "grant_type": "refresh_token",
    })
    response.raise_for_status()
    return response.json()["access_token"]


def ensure_event(client, token, action):
    """Stable provider event ID reconciles timeout/409 without duplicate inserts."""
    remote_id = hashlib.sha256(action["id"].encode()).hexdigest()
    headers = {"Authorization": f"Bearer {token}"}
    existing = client.get(f"{API}/{remote_id}", headers=headers)
    if existing.status_code == 200:
        event = existing.json()
        if event.get("extendedProperties", {}).get("private", {}).get("lifescript_action") != action["id"]:
            raise ValueError("calendar_event_identity_conflict")
        return remote_id
    if existing.status_code != 404:
        existing.raise_for_status()
    payload = action["payload"]
    response = client.post(API, headers=headers, json={
        "id": remote_id, "summary": payload["summary"],
        "start": {"dateTime": payload["start"]}, "end": {"dateTime": payload["end"]},
        "extendedProperties": {"private": {"lifescript_action": action["id"]}},
    })
    if response.status_code == 409:
        # Never assume every 409 is our event; verify identity on retry/read.
        again = client.get(f"{API}/{remote_id}", headers=headers)
        again.raise_for_status()
        if again.json().get("extendedProperties", {}).get("private", {}).get("lifescript_action") != action["id"]:
            raise ValueError("calendar_event_identity_conflict")
    else:
        response.raise_for_status()
    return remote_id


def process_calendar_action(repo):
    action = repo.rpc("claim_calendar_action", {})
    if not action:
        return False
    try:
        with httpx.Client(verify=tls_context(), timeout=30) as client:
            token = access_token(repo.db, action["user_id"], client)
            remote_id = ensure_event(client, token, action)
        values = {"status": "completed", "remote_id": remote_id, "error_code": None}
    except Exception:
        # Unknown external outcomes are reconciled by stable ID on retry, not blindly repeated.
        values = {"status": "uncertain" if action["attempts"] >= 3 else "approved",
                  "error_code": "calendar_execution_needs_retry",
                  "available_at": (datetime.now(timezone.utc) + timedelta(minutes=1)).isoformat()}
    repo.db.table("calendar_actions").update(values).eq("id", action["id"]).eq("lease_token", action["lease_token"]).eq("status", "running").execute()
    return True
