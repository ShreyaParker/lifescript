# Development and operations guide

> Baseline audit snapshot, before the implementation changes. See [current implementation](current-implementation.md), [progress tracker](implementation-progress.md), and [verification results](verification-results.md) for the updated state.

## Prerequisites and limits

Use a Flutter installation compatible with Dart `^3.9.0` and the checked lockfile's Flutter `>=3.35.0` requirement, a Python environment compatible with the resolved requirements, and an isolated Supabase development project. Python 3.13 is available in the reviewed environment, but the repository declares no supported Python version and this review does not certify dependency compatibility. Pin and test a version before documenting it as supported.

Current inference requires Gemini access. The local-model path in [free AI tools](free-ai-tools.md) is proposed and needs an adapter; setting an Ollama URL alone does not change the current code.

Do not run the manual `test_*.py` scripts or `delete_user.py` against a personal/production database. Several issue live writes on import; the deletion script targets a hardcoded account. The normal setup below intentionally excludes them.

## Backend local setup (PowerShell)

From repository root:

```powershell
Set-Location backend
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
```

Create `backend/.env` locally with actual development values; it is ignored by the current root `.gitignore`:

```dotenv
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_SECRET_KEY=YOUR-BACKEND-ONLY-KEY
SUPABASE_JWKS_URL=https://YOUR-PROJECT.supabase.co/auth/v1/.well-known/jwks.json
GEMINI_API_KEY=YOUR-DEVELOPMENT-KEY
```

Never copy the backend key into Flutter or browser configuration. JWKS is currently required but unused. The environment file example is documentation only; no secret file was created by this task.

The checked SQL is **not** a clean-install migration. Reconcile/provision the missing base schema using [database notes](database.md) before expecting journal/task routes to work. Do not apply SQL to an existing database without inspecting it.

Start the API, from `backend`:

```powershell
.\venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Open `http://127.0.0.1:8000/docs`. GET `/` only proves the app responds; it does not test the database, auth provider, or model provider.

## Frontend local setup

In a second terminal, from repository root:

```powershell
Set-Location frontend
flutter pub get
flutter run -d chrome --web-port 8080
```

The browser port matches the hardcoded OAuth redirect and an allowed CORS origin. Configure Supabase/Google OAuth development callback allowlists separately. Current public Supabase URL/publishable key live in `lib/main.dart`; move them to environment build configuration for portability. A publishable key is intended for client distribution, but safe data access still depends on correct RLS.

For mobile, replace hardcoded API URLs with target-specific configuration. Android emulator generally needs `http://10.0.2.2:8000`; physical devices need a reachable host and a server bind appropriate to the development network. Release builds need HTTPS and correct manifest/deep-link configuration. Current code has not been prepared for that switch.

## Verification commands and caveats

```powershell
Set-Location frontend
flutter analyze --no-pub
```

`flutter test` currently contains the stale counter-app test; replace it with auth/router/provider fixtures before treating its result as a quality signal. Avoid a blanket `pytest` run until manual probe scripts are isolated. See [testing and evaluation](testing-and-evaluation.md) for safe checks and review results.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Backend fails during import | Required environment values; launch directory; installed dependencies |
| Onboarding loops after restart | Zero-ID write versus real user read; false success on DB exception |
| API success but task checkbox fails | Missing returned task ID, missing list endpoint, task ownership |
| Nexus ignores new tasks | Singleton state is separate from taskProvider |
| Browser works but emulator fails | Loopback address, server bind, network policy and release manifest |
| Canvas parse key error only | `os.getenv` versus Pydantic settings source; unused ApiClient |
| “Upload failed” after journal was saved | Post-write model/task/cache failure; no atomicity/idempotency |
| Bypass button returns to login | Router requires a real Supabase session |
| Analytics look identical for every account | Resonance and Gallery values are static demo data |

## Proposed deployment baseline

No Dockerfile, Compose configuration, CI workflow, health/readiness probes, or deployment manifest is present. Implement these after first fixing auth and contracts:

1. A reproducible backend image, non-root process, pinned dependencies, and environment-injected secrets.
2. Explicit web origin/callback configuration and environment-specific Flutter builds.
3. Separate migration execution from app startup; validate schema version before serving.
4. Liveness for process health and readiness for required storage/connectivity; keep expensive model calls out of probes.
5. HTTPS, bounded request size, authentication, per-user quotas, provider timeouts, and sanitized centralized logs.
6. Durable jobs with retries/leases if enrichment runs asynchronously. In-process background tasks alone are not durable across restart.
7. Database backups/restore rehearsal, deletion handling, and a minimal incident runbook.
8. CI: safe backend tests, static checks, Flutter analyze/tests, build artifacts, and migration checks against disposable data.

A local demonstration can remain free of hosted inference charges with local models and an existing computer. Hosted compute, public uptime, backups, email, app-store distribution, and hardware are separate costs; no perpetual free cloud deployment is promised here.
