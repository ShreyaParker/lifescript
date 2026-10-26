import pytest

from app import hosted


def test_hosted_refuses_ephemeral_checkpoint_store(monkeypatch):
    monkeypatch.delenv("CHECKPOINT_DATABASE_URL", raising=False)
    with pytest.raises(SystemExit, match="CHECKPOINT_DATABASE_URL"):
        hosted.main()


def test_worker_exit_stops_api_and_fails_host(monkeypatch):
    monkeypatch.setenv("CHECKPOINT_DATABASE_URL", "postgresql://unused")
    monkeypatch.setenv("PORT", "12345")
    monkeypatch.setattr(hosted.signal, "signal", lambda *args: None)
    children = []

    class Child:
        def __init__(self, command):
            self.command = command
            self.code = 1 if command[-1] == "app.worker" else None
            children.append(self)

        def poll(self):
            return self.code

        def terminate(self):
            self.code = -15

        def wait(self, timeout=None):
            return self.code

    monkeypatch.setattr(hosted.subprocess, "Popen", Child)
    assert hosted.main() == 1
    assert children[0].code == -15
    assert "12345" in children[0].command
    assert "--no-access-log" in children[0].command
