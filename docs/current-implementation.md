# Current implementation

Deployment addition: `python -m app.hosted` supervises API and worker together for a single sleeping Render Free demo service, using the platform PORT and mandatory CHECKPOINT_DATABASE_URL. `render.yaml` configures this mode; docs/free-deployment.md covers external account setup and APK signing. This topology has no always-on background processing and has not been cloud/container verified. Existing separate-process development and Compose topology remains available.

Implemented locally across 22 and 23 October 2026. See [progress](implementation-progress.md) for release gates; the older architecture documents describe the pre-implementation audit snapshot.

## Runtime architecture

Flutter -> authenticated FastAPI -> Supabase/Postgres for canonical users, journals, tasks, media, assets, workflow runs and automation rules. A separate Python worker claims database jobs with expiring leases and heartbeat renewal, runs LangGraph, and publishes clarification/review states. Users approve selected tasks; a backend-only RPC commits persisted tasks and terminal run status atomically.

Graph checkpoints use local SQLite for one development worker or a private PostgreSQL schema for multi-worker use. Checkpoints are not stored in Supabase's public schema. `AI_PROVIDER=ollama` is the default; Gemini is an explicit configured adapter. The application has no fake AI fallback: unavailable processing becomes a visible retryable/failed run while the entry remains saved.

## Active modules

| Location | Responsibility |
| --- | --- |
| `backend/app/core/` | Lazy credential-dependent clients, strict bearer authentication, config, streamed body limit and safe JSON logs |
| `backend/app/routers/workflows.py` | Versioned journal/run/review/source-correction, upload, memory, export and automation APIs |
| `backend/app/routers/objectives.py` | Authenticated canonical goals/projects and stable operation IDs |
| `backend/app/services/assistant.py` | Read-only LangGraph retrieval and cited structured answer, with quote validation |
| `backend/app/routers/calendar.py` | Separate calendar connection/consent and action approval APIs |
| `backend/app/services/planning_graph.py` | Typed understanding, clarification interrupt, bounded plan validation, review interrupt |
| `backend/app/services/workflow_repository.py` | Owner predicates, RPC error translation, hybrid retrieval, conditional versioned memory indexing |
| `backend/app/services/model_provider.py` | Local/hosted structured outputs and embedding batches, dimensions/finiteness, output budget, timeouts and bounded schema repair |
| `backend/app/services/asset_service.py` / `media_worker.py` | Signature/size checks, image observation and isolated PDF/audio/OCR parsing |
| `backend/app/services/calendar_service.py` | Encrypted refresh-token handling, event identity reconciliation and action execution |
| `backend/app/worker.py` | Claims, checkpoint persistence, failure recovery, scheduling, calendar jobs and retention cleanup |
| `backend/migrations/` | Ordered core, workflow, memory, automation, calendar and retention schema/RPC/grant definitions |
| `backend/tests/` | Safe isolated regression tests plus opt-in disposable Postgres integration tests |
| `frontend/lib/services/` | Shared authenticated client and centralized sign-out/local cleanup |
| `frontend/lib/state/` | Session-dependent canonical tasks/profile/workflows; immutable task updates |
| `frontend/lib/features/` | Real Canvas/Nexus/Gallery/Resonance, automation/calendar controls and memory management |

Legacy standalone agents/services and the older dashboard remain unrouted/reference code. Active routes use the shared provider and workflow implementation. The old local Nexus/Gallery singleton stores were removed.

## User journey

1. Sign in through Supabase; callback checks profile completion. Onboarding writes the authenticated user's actual goals.
2. Canvas maintains an account-scoped local draft and stable operation key across network retries/restarts. Protected screen state is recreated on owner changes; API clients reject requests whose current session no longer matches their owner.
3. Optional uploads reserve owned pending metadata before object-store I/O, then become ready only after successful storage/finalization. Pending assets cannot enter a workflow and remain visible for cleanup after interruption. Formats are PNG/JPEG, PDF and enabled audio. Per-file default is 10 MB, PDF maximum 30 pages, server audio maximum five minutes; UI recordings stop after two minutes or dispose with their screen.
4. Entry/run creation is one transaction with owner-scoped idempotency. The worker extracts bounded source context, retrieves relevant owned memory/goals/tasks and builds a proposal.
5. Clarification pauses until an answer. Review permits selection, title/description editing, rejection and approval. Extracted text can be corrected; a new graph revision replaces the stale proposal and invalidates old memory chunks.
6. Committed tasks appear in Nexus with actual IDs and persisted completion state. Gallery uses logged media; Resonance reports actual seven-day counts rather than invented scores.
7. Automation rules generate drafts or in-app reminders at relative intervals. Calendar writes require their own connection and per-action approval; drafts do not write events.

## API surface

All routes except liveness/root and the state-protected OAuth callback require bearer authentication. FastAPI `/docs` describes typed inputs.

| Route | Purpose |
| --- | --- |
| POST `/onboarding/setup` | Authenticated bounded profile setup; caller cannot set owner |
| GET `/tasks`, GET `/tasks/archive`, PATCH `/tasks/{id}/toggle` | Canonical owner-scoped tasks and validated UTC date archive |
| GET `/profile/`, POST `/profile/goals`, POST `/profile/media` | Actual profile/goals/media |
| POST `/journal/submit` | Compatibility enqueue endpoint, 202 with entry/run IDs and no unapproved tasks |
| GET `/journal/audit` | Deterministic seven-day reflection/task-status counts |
| POST `/canvas/parse` | Authenticated legacy structured entity extraction; not used by current Canvas |
| POST/GET `/v1/entries`, DELETE `/v1/entries/{id}` | Save/list/forget entries; create requires `Idempotency-Key` |
| GET `/v1/runs`, GET `/v1/runs/{id}` | Owned processing/review status |
| POST `/v1/runs/{id}/clarification`, `/decision`, `/retry` | Resume interaction or retry processing |
| PATCH `/v1/runs/{id}/proposal`, `/sources` | Versioned edits or corrected-source reprocessing |
| POST/GET `/v1/assets`, GET/DELETE `/v1/assets/{id}` | Owned private uploads, listing, download and unused-attachment deletion |
| GET `/v1/memory?q=...`, `/v1/export`, `/v1/capabilities` | Inspect memory, capped data export and enabled media capabilities |
| GET/POST `/v1/automations`, PATCH `/v1/automations/{id}`, GET `/v1/automation-events` | Opt-in rules, pause and history |
| GET/DELETE `/v1/calendar/connection`, POST `/v1/calendar/connect`, GET `/v1/calendar/callback` | Separate scoped calendar consent and local disconnect |
| GET/POST `/v1/calendar/actions`, POST `/v1/calendar/actions/{id}/decision` | Event drafts, explicit approval/rejection and reconciliation retry |
| GET `/health/live`, `/health/ready` | Process liveness and required schema connectivity |

## Important semantics and limits

- Journal saving is separate from AI completion and task approval. No HTTP timeout is described as a lost journal if a run was already acknowledged.
- Proposals contain up to five tasks, exact source excerpts and bounded XP/duration; total duration is capped at 240 minutes. Automatic due-date/dependency scheduling is not implemented yet.
- An identical idempotency key/payload returns the same run; key reuse with a different payload conflicts. Hourly entry creation is capped at 30 per owner in SQL; legacy inline parsing is capped at ten calls per owner/hour.
- Source/model outputs are untrusted. Ownership, state/version, selection and schema rules run outside the model. No arbitrary SQL/tool execution is exposed.
- Search uses owner-filtered full text and compatible-model vectors, with keyword fallback during embedding outage. Quality is not yet benchmarked; no reranker is assumed.
- Source context is bounded to 30,000 characters; searchable overlapping chunks are capped at 32 per run. Large files can be only partly included, so verify evidence for long-document use cases.
- Forgetting an entry removes active runs/memory immediately; worker checkpoint/storage cleanup is deferred at least one hour to avoid racing active processing. Approved tasks remain independent, including their descriptions/evidence. Backups follow the operator's retention policy.
- Calendar events use user-selected times with offsets, separate encrypted credentials, explicit approval and stable remote event IDs. Disconnect stops future local credential use; already in-flight external calls may complete. Removing the provider-side OAuth grant is a separate Google-account operation.
- Attachment storage is capped at 50 files / 100 MiB per owner. Unused uploads can be removed from the memory screen; orphan cleanup queues uploads unreferenced for seven days.
- Pausing a rule cancels its queued/running draft jobs. In-flight provider calls may finish, but stale leases prevent their result from being published or committed. Relative automation intervals are not timezone/quiet-hour schedules. Reminders are in-app events, not push/email notifications.
- SQLite checkpoints require one worker and persistent disk. Native release configuration, containers, real OAuth, Postgres functions and optional model engines require service verification.

## Daily interface (23 October 2026)

The main shell opens Today (approved tasks, actual completion progress and journal shortcut), followed by Journal (existing Canvas workflow) and Review (seven-day reflection). Memory search is in the app bar. Profile/goals, saved media, automation/calendar and sign-out are in the account/tools menu. Media and automation use authenticated account-scoped secondary routes. Main content is capped at 960px. Goal/project/task relationships and grounded conversational chat remain planned; existing macro goals display without inferred completion scores.

## Canonical goals and grounded assistant (23 October 2026)

This section supersedes the earlier daily-interface roadmap: Today, Journal, Goals and Assistant are implemented main screens. Weekly Review moved to the secondary tools menu. The selected development database is now schema 12 after a reviewed version-11 audit and additive 0012 migration. API and worker require version 12.

New routes: GET/POST `/v1/objectives`, PATCH `/v1/objectives/{id}` (title/status), PATCH `/tasks/{id}` (title/details/owned objective link), GET `/v1/entries/{id}`, POST `/v1/assistant`. Export now includes objectives. New goals/projects are canonical rows; valid onboarding macro goals backfill and synchronize by deterministic ID. Existing profile north-star data remains preserved. Objectives support manual closure; task completion does not fabricate goal achievement. Progress is explicitly over loaded tasks (latest 100 by default), not a lifetime or date-filtered total.

Assistant retrieves up to eight memory chunks (current RPC returns at most six) plus 30 recent tasks and 30 objectives, sends up to four preceding conversation turns as untrusted context, and validates every returned quote against an owned source. Sources and prompts are never executable tools. The inline-model quota is shared with legacy parsing (ten calls/owner/hour). Chat does not persist history or make writes. Citation existence checks cannot establish factual entailment; broad grounded-answer evaluation remains pending.

Verified platform TLS trust fixes managed Windows certificate failures without disabling checks. Gemini JSON Schema transport preserves Pydantic additional-property constraints and local validation. Model HTTP retries are explicitly bounded; the leased worker controls durable retries. Reflection intent skips unnecessary task generation. A quota failure stays visible, preserving the saved entry and using a five-minute retry backoff.

`app.database_audit` provides read-only schema metadata, an ordered SQL bundle, and an explicitly selected project/version/RLS-checked additive migration-0012 option. `app.smoke_journey` is main-guarded and requires an explicit write flag; generation-fixture mode is test-only, never an application provider fallback. `scripts/start-dev.ps1` launches/restarts workspace-specific hidden processes. `app.serve_web` serves the built web app locally without logging OAuth query strings.

## Shared visual system (23 October 2026)

`core/theme/app_theme.dart` owns the palette, typography and Material component styling. Inter and Manrope are bundled locally in assets/fonts with OFL licenses registered at startup. Headings have explicit colors/variable-font weights for consistent contrast. `shared/widgets/design.dart` contains finite entrance motion, hover surfaces, section headings, empty states and native vector artwork; no generated raster or external image service is required.

`WorkspaceFrame` implements the >=880px sidebar and smaller-screen bottom navigation. Its animated IndexedStack keeps existing page state, mutes hidden tickers and respects reduced motion. Today presents actual loaded task/goal counts; goal cards use actual linked-task progress. `JournalComposer` is presentation-only, keeping auth/recording/idempotency in CanvasScreen. Assistant retains cited answers and bounded history, adds automatic reply scrolling and visible inline errors. No new model calls, analytics or backend state semantics were introduced by the redesign.
