from copy import deepcopy
from langgraph.checkpoint.sqlite import SqliteSaver
from app.services.planning_graph import build_graph
from app.worker import work_once
from test_planning_graph import FakeProvider, INITIAL


class WorkerProvider(FakeProvider):
    embedding_model = "test:768"
    def embed(self, text): return [0.0]*768


class WorkerRepo:
    def __init__(self):
        self.run = {"id":"run-1","entry_id":"entry-1","user_id":"owner-1","asset_ids":[],
                    "timezone":"Asia/Kolkata","status":"queued","attempts":0,"lease_token":"lease-1","version":1}
        self.committed = []
        self.fail_commit = False
        self.claims = 0
    def claim(self):
        if self.run["status"]!="queued": return None
        self.run.update(status="running",attempts=self.run["attempts"]+1)
        self.claims += 1
        return deepcopy(self.run)
    def update_claim(self, run, values): self.run.update(values)
    def context(self, run): return {"content":INITIAL["content"],"created_at":INITIAL["reference_time"]}, INITIAL["goals"], []
    def search(self, *args): return []
    def index(self, *args): pass
    def owned_run(self, *args): return deepcopy(self.run)
    def commit(self, run, decision):
        if self.fail_commit:
            self.fail_commit = False
            raise RuntimeError("temporary storage outage")
        self.committed = decision["selected_indices"]
        self.run["status"] = "completed"


def test_worker_does_not_commit_before_approval_and_recovers_commit_failure(tmp_path):
    repo,provider=WorkerRepo(),WorkerProvider()
    with SqliteSaver.from_conn_string(str(tmp_path/'checkpoint.sqlite')) as saver:
        graph=build_graph(provider,saver)
        assert work_once(repo,provider,graph)
        assert repo.run["status"]=="awaiting_review" and repo.committed==[]
        repo.run.update(status="queued",resume_data={"decision":"approve","version":1,"selected_indices":[0]})
        repo.fail_commit=True
        assert work_once(repo,provider,graph)
        assert repo.run["status"]=="queued" and repo.committed==[]
        assert work_once(repo,provider,graph)
        assert repo.run["status"]=="completed" and repo.committed==[0]
        assert not work_once(repo,provider,graph)
        assert provider.calls==2


def test_permanent_file_failure_does_not_consume_repeated_model_retries(monkeypatch):
    import app.worker as worker
    def fail(*args): raise ValueError("scanned_pdf_requires_ocr")
    monkeypatch.setattr(worker,"process_run",fail)
    repo=WorkerRepo()
    worker.work_once(repo,None,None)
    assert repo.run["status"]=="failed"
    assert repo.run["error_code"]=="scanned_pdf_requires_ocr"


def test_quota_failure_is_explicit_and_backs_off(monkeypatch):
    import app.worker as worker
    from datetime import datetime, timezone
    class QuotaError(Exception):
        code = 429
    def fail(*args):
        raise QuotaError('not exposed')
    monkeypatch.setattr(worker, 'process_run', fail)
    repo = WorkerRepo()
    before = datetime.now(timezone.utc)
    worker.work_once(repo, None, None)
    assert repo.run['status'] == 'queued'
    assert repo.run['error_code'] == 'provider_quota_exceeded'
    assert (datetime.fromisoformat(repo.run['available_at']) - before).total_seconds() >= 299
