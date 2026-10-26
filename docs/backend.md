# Backend technical reference

> Baseline audit snapshot, before the implementation changes. See [current implementation](current-implementation.md), [progress tracker](implementation-progress.md), and [verification results](verification-results.md) for the updated state.

## Stack and layering

`backend/requirements.txt` declares FastAPI, Uvicorn, Pydantic, pydantic-settings, Supabase, python-jose with cryptography, passlib with bcrypt, python-multipart, google-genai, pytest, httpx, and python-dotenv. Versions are unpinned. JWT validation currently uses Supabase Auth rather than the declared jose dependency; password hashing and multipart handling have no active application call site.

The application has router, core, agent, service, and schema directories. `models/` only contains an empty initializer: there is no ORM/domain-model layer. Database access uses the Supabase client's table/query interface directly inside routers.

| Source under `backend/app/` | Responsibility |
| --- | --- |
| `main.py` | Creates app, CORS, router mounts, catch-all exception handler, root response |
| `core/config.py` | Import-time `Settings()` construction from process environment / working-directory `.env` |
| `core/db.py` | Import-time global Supabase client and `get_db` dependency |
| `core/security.py` | Optional bearer parsing, zero-UUID fallback, remote token validation |
| `routers/onboarding.py` | Four-field profile setup, unauthenticated user ID in body |
| `routers/journal.py` | Embedding, journal write, task generation/persistence, historical audit |
| `routers/tasks.py` | Completion status update and date archive |
| `routers/profile.py` | Profile/media retrieval, goal replacement, media insert |
| `routers/canvas.py` | Unauthenticated media/hobby extraction with optional key header |
| `agents/scriptwriter.py` | Single Gemini request for tasks and coaching |
| `agents/auditor.py` | Single Gemini request for repeated patterns and optional adjustment |
| `agents/resonance.py` | Unused image-plus-date analysis method |
| `services/embedding_service.py` | Gemini embedding request with requested dimension 768 |
| `services/onboarding_service.py` | Unused conversational onboarding service |
| `schemas/task.py` | `ExtractedTask`, `ScriptwriterOutputSchema` |
| `schemas/audit.py` | `Adjustment`, `AuditResultSchema` |
| `schemas/onboarding.py` | `ProfileProgress`, `OnboardingSessionSchema` for unused chat flow |

## Startup and configuration

Settings are required even for tests importing `app.main`. Missing credentials prevent import/startup. `env_file=".env"` resolves relative to the process working directory; launch Uvicorn from `backend`.

| Variable | Meaning | Current use |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase project API URL | Client initialization |
| `SUPABASE_SECRET_KEY` | Environment alias for `Settings.SUPABASE_KEY` | Backend database/auth client |
| `SUPABASE_JWKS_URL` | Configured JWKS endpoint | Required but unused by validation code |
| `GEMINI_API_KEY` | Server model-provider credential | Journal, audit, and service constructors |

Canvas uses `os.getenv("GEMINI_API_KEY")` rather than the Settings value. A value read only from the Pydantic `.env` is not guaranteed to exist in `os.environ`; Canvas may therefore fail while other AI paths work. Unify provider configuration and inject one tested adapter.

## Request handling

Protected routes call `get_current_user`, which returns the zero UUID when no credentials are supplied. With a token, `db.auth.get_user(token)` validates through Supabase and returns the user's ID. Onboarding and Canvas do not use this dependency. This is the first authorization boundary to repair.

Journal submission performs these operations serially:

1. Build a fresh embedding client and embed the supplied content.
2. Upsert a placeholder email for the current user, even if a real profile already exists.
3. Insert the journal with content and vector; check for returned data.
4. Call a fresh Scriptwriter instance with fixed goals.
5. Insert a task batch, ignoring the returned rows.
6. Return the local task dictionaries and a coaching string.

No length constraints, empty-input guard, request key, transaction, source-entry relationship, or model-error classification is implemented. An empty task list is still passed to `insert`; its behavior must be tested with the chosen client/version.

Audit selects only content from the latest seven rows sorted newest first. Fewer than three entries yields a non-model fallback. Otherwise, it uses hardcoded goals and supplies that newest-first list to a prompt describing chronological logs. It does not fetch task completion or check a time interval.

## Error and concurrency behavior

Most routers catch every exception and rethrow HTTP 500 with the exception string. Task toggle's own 404 is caught this way and becomes 500. Onboarding instead catches a failed write and returns an HTTP 200 success payload with a `developer_note`.

The catch-all handler writes traceback text to a relative `error_log.txt` and includes `str(exc)` in the response. It lacks rotation, redaction, correlation IDs, and structured fields. Sensitive provider/database details can escape through error responses. Router-handled HTTPExceptions generally bypass that catch-all handler.

All Gemini `models.generate_content` / `embed_content` calls and Supabase `.execute()` calls are synchronous. Merely declaring the enclosing function async does not make them nonblocking. Introduce asynchronous adapters where supported or explicitly offload synchronous calls; bound concurrency, timeouts, and retries. Use a durable worker for long AI processing as described in the [target design](target-system-design.md).

## Cleanup direction

Keep one FastAPI application, but make routers thin. Introduce authenticated application services, repository interfaces, model-provider interfaces, shared request/response schemas, and lifecycle-managed clients. Remove unused dependencies after confirming usage; retain the unused image/chat experiments only if they have a roadmap owner. Pin a reproducible dependency set before deployment.
