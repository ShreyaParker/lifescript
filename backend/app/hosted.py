"""Single-instance demo host: supervise API and worker without storing local state."""
import os
import signal
import subprocess
import sys
import threading


def main():
    # Render's filesystem is ephemeral. Refuse accidental SQLite checkpoints.
    if not os.environ.get("CHECKPOINT_DATABASE_URL", "").strip():
        raise SystemExit("CHECKPOINT_DATABASE_URL is required for hosted checkpoints")
    port = int(os.environ.get("PORT", "10000"))
    if not 1 <= port <= 65535:
        raise SystemExit("PORT must be between 1 and 65535")
    stopped = threading.Event()
    for name in (signal.SIGTERM, signal.SIGINT):
        signal.signal(name, lambda *_: stopped.set())
    children = []
    result = 0
    try:
        commands = [
            [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0",
             "--port", str(port), "--workers", "1", "--no-access-log"],
            [sys.executable, "-m", "app.worker"],
        ]
        for command in commands:
            children.append(subprocess.Popen(command))
        while not stopped.wait(0.5):
            if any(child.poll() is not None for child in children):
                # A healthy API with a dead worker must not remain deployed.
                result = 1
                break
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
        for child in children:
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
    return result


if __name__ == "__main__":
    sys.exit(main())
