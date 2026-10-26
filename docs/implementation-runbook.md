# Implementation runbook

For the Render Free + Vercel + existing Supabase deployment and signed Flutter APK, follow [free deployment](free-deployment.md). Its single-service API/worker supervisor is for a sleeping demo; it requires private PostgreSQL checkpoints. Standalone development/Compose remains as described below.

See [progress](implementation-progress.md) and [current implementation](current-implementation.md) before running the upgraded application. The selected development database was audited and upgraded from schema 11 to 12 on 23 October 2026; earlier baseline notes below remain relevant for a fresh installation.

## Backend setup

From the repository root, PowerShell:

```powershell
Set-Location backend
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.lock
if (-not (Test-Path -LiteralPath .env)) { Copy-Item .env.example .env }
```

Do not overwrite an existing `.env`; merge the new nonsecret options into it instead. Configure Supabase URL and a backend-only service credential locally. Keep secrets out of Flutter, Git, traces and documentation.

Use a dedicated Supabase development project. Review its actual schema, auth relationship, grants and policies, then apply `backend/migrations/0001_core.sql` through `0012_objectives.sql` in order. The baseline intentionally tightens profile policies and disables direct client domain writes; existing shared-project policies require explicit reconciliation. The older `backend/supabase_migrations.sql` is a historical prototype, not the migration entrypoint for this version.

The migrations create the private `journal-assets` bucket, owner-scoped workflow RPCs and private checkpoint schema. Verify Storage policies do not independently expose bucket objects. Test both a fresh install and the existing development schema before using real data.

## Model configuration

Local default:

```dotenv
AI_PROVIDER=ollama
OLLAMA_URL=http://127.0.0.1:11434
OLLAMA_MODEL=gemma3:4b
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
```

Install/start Ollama and explicitly download models suitable for the computer. The example model names are starting configurations, not benchmark winners or a guarantee of hardware fit. Embeddings must return 768 finite values. Use the same provider/model/version for indexed and query vectors.

For hosted Gemini, set `AI_PROVIDER=gemini`, `GEMINI_API_KEY` and a currently available `GENERATION_MODEL`/`EMBEDDING_MODEL`. Verify account quota and permitted data processing; use synthetic entries for unpaid-service experiments. The code does not silently fall back to a hosted model.

The local development `.env` was switched to Gemini on 23 October 2026 using the existing private key. Settings loading confirms the provider and key presence; no hosted request was made. Ollama is not required for this configuration. Restart both API and worker after changing `.env`; Flutter does not need the Gemini key. The configured model names remain subject to account availability and quota.

Start the API and worker in separate terminals from `backend`:

```powershell
.\venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-access-log
.\venv\Scripts\python.exe -m app.worker
```

`--no-access-log` avoids logging OAuth callback authorization codes in query strings. Application logs use safe JSON fields and omit raw journals/tokens. `/health/live` checks the process; `/health/ready` verifies required database access. Without the worker, entries remain queued and safe to retry later.

If an older running process reports `ClientOptions` has no attribute `storage`, restart API and worker with the updated code: database initialization now uses `SyncClientOptions` required by the synchronous Supabase SDK. This correction does not require a package upgrade or schema change.

The default `.local/checkpoints.sqlite` is for one worker with persistent disk. For multiple workers set `CHECKPOINT_DATABASE_URL` to a direct/pooler database connection compatible with the Postgres checkpointer. The worker restricts its search path to `lifescript_private`; migration 0006 must exist first. Do not place checkpoint tables in an exposed schema or expose that DSN to clients.

## Optional speech and OCR

```powershell
.\venv\Scripts\python.exe -m pip install -r requirements-multimodal.txt
```

This optional environment is not included in the verified core lockfile; test/pin its resolved versions on the target worker before release. Preload models and verify dependencies, resources and licenses. Set `ENABLE_AUDIO=true` only after faster-whisper works with actual recordings; set `ENABLE_DOCLING=true` after testing OCR. PDF/audio/OCR parsing runs in a separate process with a timeout; deploy with container memory/CPU limits as well. The Docker core image does not install these heavy optional engines.

## Frontend setup

From `frontend`:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_URL=http://127.0.0.1:8000
```

Override `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` for another project. The default project is `https://bimjjeyprywffqjezyhy.supabase.co`; its public key matches the local backend configuration and is not a service credential. `AUTH_REDIRECT_URL` overrides the web origin/native callback default. Configure Supabase and Google callback allowlists. Android emulator API access normally uses `10.0.2.2`; physical devices need a reachable host and suitable HTTPS/network configuration.

Android INTERNET/microphone permissions and a native OAuth scheme are supplied; iOS includes microphone usage text and URL scheme. Native builds remain unverified. Android release no longer uses debug signing: provide ignored `android/key.properties` and a protected keystore; otherwise artifacts are unsigned.

## Optional calendar connection

Configure a separate Google OAuth client with the callback URL in `.env`. Set `GOOGLE_CALENDAR_CLIENT_ID`, `GOOGLE_CALENDAR_CLIENT_SECRET`, `GOOGLE_CALENDAR_REDIRECT_URL`, and `TOKEN_ENCRYPTION_KEY`. Generate the encryption key privately using `Fernet.generate_key()`; never paste it into chat/docs or commit it. Preserve it securely across deployments; losing it prevents decryption of stored refresh tokens.

The Automation screen starts explicit Google consent for owned-calendar events. After callback, return to the app and refresh connection status. Draft an event, review its title/times, then approve. A worker writes it using a stable event ID. Unknown outcomes are marked/reconciled, not blindly duplicated. Test with a development calendar/account. No real calendar was connected during implementation.

## Tests and evaluation

```powershell
# From root:
backend\venv\Scripts\python.exe -m pytest
# From frontend:
flutter analyze --fatal-infos
flutter test
flutter build web --release
```

Postgres integration tests require `LIFESCRIPT_TEST_DATABASE_URL` pointing only to a local disposable database ending in `_test`, with pgvector available. They create stub auth/storage schemas, exercise migrations/RLS/RPC behavior, and roll back DDL/data. Never point them at a real Supabase project. CI provisions a disposable pgvector service automatically; CI itself was not run locally.

Optional synthetic AI evaluation from `backend`:

```powershell
.\venv\Scripts\python.exe -m app.evaluate --split held_out --limit 10 --output .local/evaluation.json
```

This makes real configured-provider calls (up to two per case before internal schema repairs). It reads only the synthetic dataset, not the database. Hosted costs/quotas may apply. Results are not precomputed or claimed by this iteration. Expand the simple action/clarification benchmark with modality and retrieval fixtures before release.

## Containers and operational checks

`docker compose up --build` runs core API/worker against the configured external development Supabase project, with a persistent checkpoint volume. It does not apply migrations or start Supabase/Auth/Ollama. The worker's default container Ollama endpoint uses `host.docker.internal`; override for the deployment topology. Containers were not started because the local Docker daemon was unavailable.

Before public use: run DB integration tests, inspect actual RLS/storage policy behavior with two users, exercise model outage/restart/double approval, confirm retention cleanup and backup restore, verify calendar revocation/uncertain outcomes, verify inline quotas/orphan-upload cleanup, and run native-device auth/media tests.

## Google sign-in project alignment (23 October 2026)

Flutter and the local backend now use `https://bimjjeyprywffqjezyhy.supabase.co`. In the Google Web OAuth client used by Supabase, authorize `https://bimjjeyprywffqjezyhy.supabase.co/auth/v1/callback`. In Supabase Authentication URL Configuration, allow `http://127.0.0.1:8080/` and `http://localhost:8080/`. Dashboard settings and a successful real sign-in remain unverified. Clear the browser site cache/service worker if an older web bundle still targets the previous project.

## Goals, assistant and development database activation (23 October 2026)

The current API and worker require schema version **12**. The existing selected Supabase development project was audited at version 11, with RLS enabled on domain tables and the expected baseline columns; only migration 0012 was applied. It creates owner-enforced goals/projects, backfills valid existing onboarding goals, synchronizes future onboarding goals without duplicate creation, and links tasks by an owner-composite foreign key. Existing profile goals become starting context; the Goals tab is the place to manage current goals/projects.

Store the development SQL DSN as `LIFESCRIPT_DATABASE_URL` in ignored `backend/.env`. Use the exact Connect dialog host, username and password; percent-encode password characters. Never put it in Flutter. From backend:

```powershell
venv/Scripts/python.exe -m app.database_audit
# Only after reviewing an identified version-11 development schema:
venv/Scripts/python.exe -m app.database_audit --apply-objectives
# Fresh-install reference bundle; review before executing in a SQL editor:
venv/Scripts/python.exe -m app.database_audit --bundle
```

The audit uses a read-only transaction and writes schema metadata, not private record contents, to `.local/schema-audit.json`. The apply option accepts only the configured Supabase project, requires RLS and version 11 with no conflicting objectives table, and applies only 0012 transactionally. Version 12 is a no-op. It does not reconcile arbitrary older schemas automatically.

HTTPS clients now use `ssl.create_default_context()` so Windows managed roots work with hostname/certificate verification enabled. Linux/container hosts must have their trusted CA certificates installed. `SSL_CERT_FILE`/`SSL_CERT_DIR` can configure an operator-provided trusted CA; do not disable TLS verification. Both Supabase and Gemini successfully connected after this correction.

Assistant questions share the existing ten-per-owner/hour inline-model quota. They retrieve owned memory plus up to 30 recent tasks and 30 objectives, validate response shape and exact citation quotes, and never mutate tasks. Up to four preceding conversation turns are sent as untrusted context; conversation is in screen memory only. Exact-quote checks do not prove that every generated statement logically follows from the quote.

Manual real-service verification is deliberately excluded from pytest:

```powershell
venv/Scripts/python.exe -m app.smoke_journey --allow-development-writes
```

This creates two newly confirmed synthetic Auth accounts without sending email, exercises the real API/model/database pipeline, then deletes only accounts created by that invocation. It calls the worker processing routine with a specifically claimed synthetic run and private temporary SQLite checkpoints, not an unrelated user's queued jobs. It reports achieved stages and cleanup in `.local/service-smoke.json`. It needs available provider quota. This is not the default safe test suite and must only target the selected development project.

### Local launch

After building Flutter web, from the repository root use `& .\scripts\start-dev.ps1 -Restart`. It restarts only this workspace's known Python service command lines and launches hidden API/worker/web processes with ignored local logs. The web server binds only 127.0.0.1:8080 and suppresses access-path logging so OAuth query strings are not written to logs. On 23 October the web/API liveness/readiness endpoints returned 200 and worker_ready was observed. These checks do not consume generation quota or prove an AI result.

When Gemini returns HTTP 429, the worker records provider_quota_exceeded, retains the saved journal, and waits five minutes before a bounded retry. Chat returns an explicit quota message. Fix/reset quota or configure a model actually available to the account; the app does not silently switch models/providers. Gemini SDK HTTP retries are limited to one transport attempt, so its internal retry loop cannot multiply the worker's retry policy. Schema-invalid outputs still receive at most one repair attempt.

For database/domain verification while generation is unavailable, `venv/Scripts/python.exe -m app.smoke_journey --allow-development-writes --fixture-generation` explicitly substitutes synthetic generation fixtures but uses real Auth/Postgres/RPCs/embeddings and cleans up only the temporary accounts it created. Stop the background worker before this targeted check to avoid racing its manual synthetic claim, then restart it afterward. This mode is not real model or answer-quality verification and is never a runtime provider fallback. A full real-model smoke remains required once quota is available.
