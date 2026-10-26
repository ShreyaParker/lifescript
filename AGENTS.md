# LifeScript working conventions

- Read `docs/implementation-progress.md`, `docs/current-implementation.md`, and `docs/implementation-runbook.md` before changing the application. Original audit documents are historical snapshots.
- After each implementation batch, update the progress tracker and `docs/verification-results.md` with completed behavior, exact checks, pending work, and service/runtime limitations. Do not mark real-service behavior verified from mocks or syntax checks.
- Run safe backend tests with `backend/venv/Scripts/python.exe -m pytest` from root. Default test discovery must never execute manual probes, live inference, admin deletion, or real database writes.
- Run Flutter analysis/tests/build appropriate to frontend changes. Do not describe a failed, skipped, interrupted, or unrun check as passing.
- Preserve authenticated ownership, proposal review, idempotency, model-output validation, private checkpoint storage, and account-scoped local state. Never reintroduce an implicit auth bypass or invented analytics.
- Keep secrets, journals, keystores, model data and checkpoints out of Git/logs. Use the ordered migration sequence; reconcile an identified development database before applying schema changes.
- Keep unrelated user work intact. Changes are local unless the user authorizes a commit/deployment or external operation.
