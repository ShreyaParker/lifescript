from uuid import uuid4

from app.core.security import get_current_user
from app.main import app
from conftest import OTHER, OWNER


def test_no_token_rejected_before_database(client):
    del app.dependency_overrides[get_current_user]
    assert client.get("/tasks").status_code == 401
    assert client.post("/onboarding/setup", json={}).status_code == 401


def test_task_toggle_is_owner_scoped(client, db):
    task_id = str(uuid4())
    db.rows["tasks"] = [{"id": task_id, "user_id": OTHER, "status": "pending"}]
    response = client.patch(f"/tasks/{task_id}/toggle", json={"is_completed": True})
    assert response.status_code == 404
    assert db.rows["tasks"][0]["status"] == "pending"


def test_task_list_and_persisted_toggle(client, db):
    own, foreign = str(uuid4()), str(uuid4())
    db.rows["tasks"] = [{"id": own, "user_id": OWNER, "status": "pending"},
                        {"id": foreign, "user_id": OTHER, "status": "pending"}]
    assert [row["id"] for row in client.get("/tasks").json()] == [own]
    assert client.patch(f"/tasks/{own}/toggle", json={"is_completed": True}).json()["new_status"] == "completed"


def test_archive_uses_half_open_interval(client, db):
    assert client.get("/tasks/archive?date=not-a-date").status_code == 422
    client.get("/tasks/archive?date=2026-10-22")
    filters = db.calls[-1][2]
    assert ("user_id", "eq", OWNER) in filters
    assert ("created_at", "lt", "2026-10-23T00:00:00+00:00") in filters


def test_onboarding_rejects_arbitrary_owner_and_preserves_email(client, db):
    payload = dict(inner_landscape="Starting", subconscious_rhythm="Evenings", intellectual_footprint="Books", core_north_star="Study")
    assert client.post("/onboarding/setup", json={**payload, "user_id": OTHER}).status_code == 422
    db.rows["users"] = [{"id": OWNER, "email": "verified@example.test"}]
    assert client.post("/onboarding/setup", json=payload).status_code == 200
    assert db.rows["users"][0]["email"] == "verified@example.test"
    assert db.rows["users"][0]["macro_goals"] == ["Study"]


def test_errors_are_truthful_and_sanitized(client, db):
    db.fail = True
    response = client.post("/profile/goals", json={"goals": ["Study"]})
    assert response.status_code == 500
    assert "PRIVATE_SENTINEL" not in response.text
    assert response.json()["request_id"]


def test_entry_submission_uses_atomic_rpc_not_model_call(client, db):
    db.rpc_result = {"id": str(uuid4()), "entry_id": str(uuid4()), "status": "queued"}
    assert client.post("/v1/entries", json={"content": "Study tomorrow"}).status_code == 422
    response = client.post("/v1/entries", json={"content": "Study tomorrow"}, headers={"Idempotency-Key": "test-entry-001"})
    assert response.status_code == 201
    name, params = db.rpc_calls[-1]
    assert name == "create_entry_run" and params["p_owner"] == OWNER
    assert len(params["p_digest"]) == 64
    assert client.post("/v1/entries", json={"content": " "}, headers={"Idempotency-Key": "test-entry-002"}).status_code == 422


def test_invalid_timezone_is_validation_error(client):
    response = client.post("/v1/entries", json={"content": "Study", "timezone": "Invalid/Zone"}, headers={"Idempotency-Key": "test-entry-003"})
    assert response.status_code == 422


def test_run_read_resume_does_not_leak_foreign_owner(client, db):
    run_id = str(uuid4())
    db.rows["workflow_runs"] = [{"id": run_id, "user_id": OTHER, "version": 1}]
    assert client.get(f"/v1/runs/{run_id}").status_code == 404
    assert client.post(f"/v1/runs/{run_id}/clarification", json={"answer": "Tomorrow"}).status_code == 404


def test_review_selection_and_scoped_resume(client, db):
    run_id = str(uuid4())
    row = {"id": run_id, "user_id": OWNER, "version": 1, "proposal": {"tasks": [{"title": "Study"}]}}
    db.rows["workflow_runs"] = [row]
    db.rpc_result = {**row, "status": "queued"}
    url = f"/v1/runs/{run_id}/decision"
    assert client.post(url, json={"decision": "approve", "version": 1, "selected_indices": [-1]}).status_code == 422
    assert client.post(url, json={"decision": "approve", "version": 1, "selected_indices": [0, 0]}).status_code == 422
    assert client.post(url, json={"decision": "approve", "version": 1, "selected_indices": [0]}).status_code == 202
    assert db.rpc_calls[-1][1]["p_owner"] == OWNER


def test_memory_scope_and_foreign_delete(client, db):
    db.rpc_result = []
    assert client.get("/v1/memory?q=Study").status_code == 200
    assert db.rpc_calls[-1][1]["p_owner"] == OWNER
    assert client.delete(f"/v1/entries/{uuid4()}").status_code == 404


def test_automation_cannot_set_owner_or_change_foreign_rule(client, db):
    body = {"name": "Review", "kind": "weekly_review", "instruction": "Review goals", "interval_hours": 168}
    db.rpc_result={"id":str(uuid4()),"user_id":OWNER,**body}
    assert client.post("/v1/automations", json={**body, "user_id": OTHER}).status_code == 422
    response = client.post("/v1/automations", json=body)
    assert response.status_code == 201 and response.json()["user_id"] == OWNER
    assert db.rpc_calls[-1][1]["p_owner"]==OWNER
    assert client.patch(f"/v1/automations/{uuid4()}", json={"enabled": False}).status_code == 404


def test_canvas_requires_authentication(client):
    del app.dependency_overrides[get_current_user]
    assert client.post("/canvas/parse", json={"text": "A book"}).status_code == 401


def test_binary_upload_rejected_without_storage_access(client):
    response = client.post("/v1/assets", files={"file": ("bad.png", b"not a PNG", "image/png")})
    assert response.status_code == 422


def test_source_corrections_cannot_invent_foreign_sources(client,db):
    run_id=str(uuid4())
    db.rows["workflow_runs"]=[{"id":run_id,"user_id":OWNER,"version":1,
        "sources":[{"source_id":"asset:page:1","content":"Old text"}]}]
    assert client.patch(f"/v1/runs/{run_id}/sources",json={"version":1,"sources":[{"source_id":"foreign","content":"Invented"}]}).status_code==422
    db.rpc_result={"id":run_id,"status":"queued","version":2}
    response=client.patch(f"/v1/runs/{run_id}/sources",json={"version":1,"sources":[{"source_id":"asset:page:1","content":"Corrected text"}]})
    assert response.status_code==202
    assert db.rpc_calls[-1][1]["p_owner"]==OWNER


def test_calendar_action_draft_requires_valid_interval_and_auth_owner(client,db):
    payload={"summary":"Study","start":"2026-10-22T10:00:00Z","end":"2026-10-22T11:00:00Z"}
    response=client.post("/v1/calendar/actions",json=payload)
    assert response.status_code==201 and response.json()["user_id"]==OWNER
    assert client.post("/v1/calendar/actions",json={**payload,"end":"2026-10-22T09:00:00Z"}).status_code==422


def test_client_body_size_limit(client):
    assert client.post("/v1/entries",content=b"test",headers={"Content-Length":"99000000"}).status_code==413


def test_weekly_review_reports_real_counts_without_simulated_scores(client,db):
    from datetime import datetime,timezone
    now=datetime.now(timezone.utc).isoformat()
    db.rows["journal_entries"]=[{"id":"entry","user_id":OWNER,"created_at":now}]
    db.rows["tasks"]=[{"id":"one","user_id":OWNER,"created_at":now,"status":"completed"},
                      {"id":"two","user_id":OWNER,"created_at":now,"status":"pending"}]
    response=client.get("/journal/audit")
    assert response.status_code==200
    assert "1 of 2 tasks" in response.json()["coaching_message"]
    assert "score" not in response.json()


def test_streamed_request_size_limit_without_content_length(client):
    def body():
        yield b"x"*(6*1024*1024)
        yield b"x"*(6*1024*1024)
    response=client.post("/v1/entries",content=body(),headers={"Idempotency-Key":"large-request-1","Content-Type":"application/json"})
    assert response.status_code==413


def test_readiness_requires_the_complete_schema(client,db,monkeypatch):
    # ready() intentionally resolves the lazy core client directly, unlike domain dependencies.
    import app.core.db as database
    monkeypatch.setattr(database,"get_db",lambda:db)
    assert client.get('/health/ready').status_code==503
    db.rows['app_schema_metadata']=[{'singleton':True,'version':11}]
    assert client.get('/health/ready').status_code==503
    db.rows['app_schema_metadata']=[{'singleton':True,'version':12}]
    assert client.get('/health/ready').status_code==200


def test_attachment_listing_is_owner_scoped(client,db):
    db.rows['assets']=[{'id':'own','user_id':OWNER,'filename':'own.pdf'},
                       {'id':'foreign','user_id':OTHER,'filename':'private.pdf'}]
    assert [row['id'] for row in client.get('/v1/assets').json()]==['own']


def test_successful_upload_is_ready_and_interrupted_upload_keeps_cleanup_metadata(client,db):
    import io
    from PIL import Image
    data=io.BytesIO();Image.new('RGB',(4,4)).save(data,format='PNG')
    response=client.post('/v1/assets',files={'file':('image.png',data.getvalue(),'image/png')})
    assert response.status_code==201
    assert db.rows['assets'][0]['status']=='ready'
    assert next(iter(db.storage.objects)).startswith(OWNER+'/')
    db.storage.fail=True
    assert client.post('/v1/assets',files={'file':('interrupted.png',data.getvalue(),'image/png')}).status_code==500
    assert db.rows['assets'][-1]['status']=='pending'
