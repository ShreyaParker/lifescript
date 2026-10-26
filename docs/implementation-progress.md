# Implementation progress

## Free deployment preparation (23 October 2026)

Added render.yaml and app.hosted: one Free Docker web service supervises a single API and worker, respects PORT, fails if either child exits, terminates both on shutdown, and refuses missing CHECKPOINT_DATABASE_URL to prevent ephemeral SQLite deployment. Existing standalone/Compose commands are unchanged. Added docs/free-deployment.md with Render/Supabase/Vercel setup, CORS/OAuth, private checkpoint configuration, signed APK instructions, deployed acceptance checks and sleeping-service limitations. Inngest is not integrated or required for this sleeping demo topology.

Verification: root backend/venv/Scripts/python.exe -m pytest **62 passed, 10 skipped** (11.85s). Added network-isolated missing-checkpoint and dead-worker/sibling-termination tests. git diff --check returned zero; deployment files are currently untracked, so that command alone does not validate their content. Docker/cloud deployment, hosted memory fit, signing/device journeys and live generation remain pending; no commit/push/deployment or private environment change performed. No Flutter source changed; frontend checks not rerun. See verification-results.md.

Last updated: **23 October 2026**. This is the authoritative progress tracker. The initial audit documents are baseline snapshots; [current implementation](current-implementation.md) and [runbook](implementation-runbook.md) describe the updated code.

Status meanings: **Implemented** = code exists; **Locally verified** = named local checks passed; **Service verification pending** = requires configured runtime/accounts/database. No milestone is called production complete merely because its files exist.

## Milestone ledger

| Milestone | Implemented in this iteration | Verification / remaining work |
| --- | --- | --- |
| 1. Reliable foundation | Mandatory auth; owner-scoped task access; real onboarding; preserved emails; task listing; session-pinned API clients; canonical Nexus/media state; real sign-out; protected screen-state reset on account changes; safe errors; bounded input; safe test discovery; dependency lock | API regression tests and Flutter analysis/tests/build pass. Supabase schema/RLS/auth callbacks require integration verification. Android/iOS target-device tests and release keystore remain pending. |
| 2. Durable text workflow | Journal/run enqueue RPC; leased worker with heartbeat/retries; LangGraph extraction, clarification and review interrupts; persistent checkpoints; edit/select/reject/approve; transactional task commit; user-controlled retry | Real SQLite checkpoint restart and commit-failure recovery tested with fake domain storage/provider. Postgres RPC integration tests are supplied but skipped locally without a disposable database. |
| 3. Personal RAG | Owner-filtered full-text/vector query; model-versioned 768-dimensional embeddings; overlapping chunks; provenance; keyword fallback; memory search; source correction/revision; active-memory deletion; deferred checkpoint/storage cleanup | Isolation/evidence/dimension cases tested. Real retrieval relevance, index plans, concurrency and hosted pgvector execution not yet measured. Reranking remains conditional on evaluation evidence. |
| 4. Multimodal | Flutter recorder with owner/disposal guards; actual file picker; private owned staged uploads; signature/image validation; image observation adapter; PDF text extraction; optional isolated faster-whisper and Docling OCR; source correction; owned attachment download/removal and quotas | Upload interruption retains pending cleanup metadata; pending assets cannot enter a workflow. Image/PDF failure paths tested. Actual model-based vision/transcription/OCR require engines, models and fixtures. Audio/OCR default disabled. |
| 5. Automation | Opt-in interval rules; transactional occurrence scheduling; in-app reminders/events; pause/resume; draft generation retains review; calendar OAuth, encrypted refresh token, action drafts/approval, leased execution, deterministic remote IDs and timeout reconciliation | Calendar adapter tested with fake HTTP provider, including uncertain external outcome. Real OAuth consent/event creation not exercised. Calendar availability reading, push/email delivery, timezone-specific clock schedules, and MCP integrations remain future extensions. |
| 6. Release quality | JSON logs/request IDs/model timings/token counters without raw journals; safe probes; synthetic eval runner/dataset; Docker/Compose; CI; opt-in disposable Postgres tests; frontend local drafts/idempotency | Python and Flutter checks run locally. Docker daemon unavailable; containers and GitHub CI not executed here. Actual AI quality benchmark, backup/restore rehearsal, device tests and production hosting remain pending. Full offline synchronization is not implemented. |

## Verification record

Startup fix (23 October 2026): database initialization now uses Supabase's `SyncClientOptions`; the base `ClientOptions` lacks synchronous auth storage and caused worker/API initialization to fail. Added a network-isolated regression exercising actual SDK construction and cached initialization. Root command `backend/venv/Scripts/python.exe -m pytest`: **49 passed, 8 skipped**. Live worker/database readiness remains pending; this test does not verify migrations or hosted services.

The final counts and execution outcomes are recorded at the end of this iteration in [verification results](verification-results.md). Earlier intermediate runs passed 21, then 28 backend tests as coverage grew. Do not confuse those intermediate counts with the final suite.

Verified mechanisms include: unauthorized requests fail before database access; cross-owner task/run access is denied by API predicates; onboarding errors do not claim success; task state uses IDs; invalid review selections are rejected; graph review resumes after reopening its SQLite store; graph completion survives a failed task-commit RPC without regenerating a plan; malformed outputs have bounded repairs; calendar timeouts reconcile by deterministic event ID.

## Existing issue disposition

References correspond to [baseline risk register](risks-and-technical-debt.md).

| Baseline IDs | Disposition |
| --- | --- |
| R01–R03, R05–R09 | Implemented fixes; local auth/ownership/API and UI checks cover representative cases. Missing task IDs are superseded by approved-plan commit results and canonical task listing. |
| R04, R10, R18 | Complete migration/RPC definitions added. Atomicity, RLS and live-schema reconciliation remain database verification gates. No live schema was modified. Schema version 12 is required for readiness/worker startup. |
| R11 | Active model work runs in a separate synchronous worker; database-backed routes use normal FastAPI functions/thread dispatch. Legacy inline parse is synchronous and bounded, with mandatory authentication. |
| R12, R14–R17 | Shared sign-out/cache cleanup, sanitized error reporting, actual goal context, honest saved/processing/review states, and real weekly counts replace misleading behavior. |
| R13 | Authentication and input bounds implemented. Entry creation and legacy inline parsing have database-enforced hourly quotas; these require live SQL verification. |
| R19, R30, R32 | Manual probes isolated/main-guarded; destructive utility requires explicit matching IDs; safe pytest paths, replacement Flutter tests, lockfile, CI and recursive ignores added. |
| R20 | Local provider is default; optional hosted configuration is explicit. No real diary/provider request was made during implementation. Deployment data policy remains an operator responsibility. |
| R21–R27, R31 | Shared client/timeouts/error mapping, embedding version/dimension checks, actual seven-day review, validated half-open archive interval, preserved emails, bounded workflow schemas, immutable ID-based task updates, and server-side provider config implemented. User-local date selection for archive remains a later UI extension. |
| R28 | Account-scoped persistent drafts and stable submission keys exist; a general offline outbox/conflict-resolution engine and encrypted local storage are still pending. |
| R29 | Main INTERNET/microphone permissions, native callback schemes, app branding, minimum Android SDK, and release keystore configuration updated. Native builds/signing and real callbacks remain unverified. |
| R33 | Simulated microphone/camera behavior removed; real recorder/file inputs added. Short video/live voice and conversational onboarding remain outside this release. |

## Service activation gates

Local configuration update (23 October 2026): switched the ignored backend `.env` to `AI_PROVIDER=gemini` for a machine without local inference capacity, preserving its existing private key. Settings loading verified configuration only; hosted generation/embeddings and account quota remain unverified. Restart API and worker to activate.

1. Review/reconcile the existing Supabase project against `backend/migrations/0001_core.sql`; it deliberately replaces legacy profile policies and tightens grants. Use a dedicated development project first.
2. Apply migrations `0001` through `0011` in order; verify RPC execution rights, profile RLS, Storage policies and a fresh install. Do not run the legacy SQL file as a competing migration system.
3. Configure a local model and embedding model; run the synthetic evaluation before accepting model quality. Hosted processing requires a suitable privacy/billing decision.
4. Run API and worker together, with persistent checkpoint storage. Use the private Postgres checkpoint schema for multiple workers; SQLite is a single-worker development option.
5. If desired, install/preload optional speech/OCR runtimes and enable them. Test actual recordings/scanned PDFs before enabling those controls for users.
6. Configure Google OAuth client/redirect and a locally generated encryption key; test calendar consent, expiry, disconnect and event approval with a test account.
7. Execute the provided Postgres integration suite, container/CI checks, native-device journey and restore rehearsal before a public release.

## Next implementation priorities

- Run the existing Postgres integration tests as soon as a disposable local pgvector database is available; fix any schema/RPC incompatibilities they expose.
- Exercise the implemented inline-parser quota, attachment quota/orphan retention, and pause cancellation with concurrent disposable-database tests; extend correction/indexing/deletion race coverage.
- Evaluate real local models across all held-out fixtures; add image/audio/document golden fixtures and measure retrieval quality/latency.
- Add availability-aware deadlines/dependencies and task editing, true timezone/quiet-hours schedules, push delivery, and a full offline outbox after the current system is exercised.
- Add a trusted MCP adapter only when a specific connected tool is selected. No speculative server or new account was connected.

## Maintenance rule

For every future change, update this ledger with changed behavior, exact verification commands/results, and remaining service gates. Keep [verification results](verification-results.md) current, and distinguish “implemented locally” from “exercised against real services.” Do not remove a pending gate without recording its evidence.

## Supabase project alignment and restart (23 October 2026)

Flutter URL and publishable key now match the existing backend project `https://bimjjeyprywffqjezyhy.supabase.co`. Required Google callback: `https://bimjjeyprywffqjezyhy.supabase.co/auth/v1/callback`. Dashboard configuration and real sign-in remain unverified. No backend secret copied to Flutter.

Checks from frontend: `D:/shreya/flutter/bin/cache/dart-sdk/bin/dart.exe analyze --fatal-infos` passed with no issues after rerunning with metadata access (initial sandbox attempt exited 1 on telemetry permissions). `D:/shreya/flutter/bin/cache/dart-sdk/bin/dart.exe D:/shreya/flutter/bin/cache/flutter_tools.snapshot build web --release` passed. Python assertions verified the built main.dart.js contains the bimjj project URL and excludes the previous project URL. Frontend tests not rerun for this configuration-only change.

Restarted API, worker and static server as hidden processes. HTTP checks: web port 8080 = 200; API /health/live = 200; /health/ready = 503, Required database schema is unavailable. Worker logs also report schema failure; background processing remains blocked. No database migrations or provider inference performed. Reconcile the database before applying ordered migrations.

## Daily-use redesign, batch 1 (23 October 2026)

Implemented Today-first navigation: Today, Journal and Review. Profile/goals, saved media and automation/calendar are secondary tools; memory search remains in the app bar. Secondary routes retain AccountScope. Added a journal shortcut, actual approved-task completion progress across all returned tasks (not just today), clearer empty/loading/error presentation, a calm green theme and a 960px main-content limit. Journal review, owner-scoped drafts and immutable task identity remain in place. No seeded personal data, credentials or alternate auth/migration systems were imported from the other project.

Checks: backend 49 passed, 8 skipped; Flutter analysis no issues; Flutter tests 5 passed, including task completion through the API and the journal shortcut. Release build outcome is in verification-results.md. No live service workflow was exercised.

Pending: reconcile development database before ordered migrations; verify the real journal/review/task journey; implement goal/project/task relationships and cited personal-memory chat with reviewable writes; run held-out quality and latency evaluations. Goals/projects and chat are not yet implemented as primary screens. Other-project code remains a reference.

## Goals, projects, assistant and development activation (23 October 2026)

Implemented four daily destinations: Today, Journal, Goals and Assistant. Weekly Review remains a secondary tool. Today has task filters and an editor to link approved tasks to goals/projects. Goals support creation with stable operation IDs, project hierarchy, renaming, completion/reopening and progress from loaded linked tasks. Migration 0012 backfills/synchronizes real onboarding goals without overwriting renamed or completed objectives. Planning uses active canonical goals/projects. Profile now shows starting direction and points to Goals for current management.

Implemented a read-only LangGraph assistant (retrieval -> structured answer -> exact citation validation), compatible-model vector retrieval with reported keyword fallback, owner-scoped task/objective context and four conversation turns. Assistant text is not an action executor. Citations prove source/quote existence, not semantic entailment. Conversation is screen-local and clears on account reset.

Fixed two real runtime defects: httpx/genai now use verified platform TLS trust; Gemini uses response_json_schema instead of the incompatible response_schema transport for nested Pydantic schemas. Explicit transport retry limit keeps worker retry policy authoritative. Intent classification skips task generation for reflections, completed work and negations; weekly-review generation remains enabled. Provider quotas are visible and back off for five minutes rather than pretending processing succeeded.

The user-selected Supabase project was inspected through REST and a read-only SQL audit at version 11. Applied only additive 0012 transactionally using a target-checked helper; re-audit confirmed version 12. Read-only checks confirmed private assets bucket, owner-composite task/objective FK and no anon/authenticated domain-table access or enqueue RPC permission. Existing user retained; journal/task counts remained zero after synthetic-account cleanup. Full fresh-install migration tests still need disposable local PostgreSQL.

Executed safe tests: **60 passed, 10 skipped**; Flutter analysis no issues; Flutter tests **8 passed**. Web build and runtime readiness final outcomes are in verification-results.md. Manual real Auth/Postgres/RPC/embedding/retrieval/account-isolation smoke passed **with explicitly labeled generation fixtures**; this is not live AI generation verification. A real-model smoke reached authenticated goal/project and journal/idempotency stages then stopped on Gemini HTTP 429; all created accounts were cleaned up. Real Gemini structured generation and 768-dimensional embeddings succeeded separately. The latest five-case development evaluation had three passing cases and two HTTP 429 failures, so no broad quality score is claimed. A candidate model probe was unsuccessful and the configured generation model was not changed.

Remaining release gates: available generation quota and a successful full real-model journey; broad held-out extraction/retrieval tests; fresh-install/concurrency Postgres suite; native-device, calendar OAuth and optional media engine checks; deployment and restore rehearsal. A local web app and portfolio guide do not certify those gates. No commit or deployment was performed.

Final runtime evidence for this batch: release web build passed in 47.6s; restarted the workspace API, single worker and safe local web server via `scripts/start-dev.ps1 -Restart`. Web, liveness and readiness all returned HTTP 200; new API routes are active and worker emitted worker_ready. Open http://127.0.0.1:8080. Provider generation quota remains unavailable; startup readiness does not certify model generation. Detailed commands and distinctions are recorded in verification-results.md.

## Modern UI redesign (23 October 2026)

Rebuilt Today, Journal, Goals and Assistant presentation with a shared indigo/lavender design system, local Inter body text and Manrope headings, stronger text hierarchy, soft gradient artwork, bordered/shadowed surfaces and more compact secondary information. Bundled both fonts and their OFL licenses; no runtime Google Fonts requests are needed. The desktop shell uses a sidebar from 880px; smaller screens retain bottom navigation. Canonical data, authenticated routes, owner-scoped drafts and explicit review controls are preserved.

Added finite fade/slide entrances, state-preserving tab transitions, pointer hover lift and task-progress interpolation. Custom motion respects reduced-motion settings, hidden pages mute tickers, and animation controllers are disposed. Chat now scrolls to new replies, keeps errors next to its input, and disables sending an empty question. Journal presentation is extracted into a stateless composer; existing upload/recorder/submission logic stays in the authenticated screen. Mobile editor height is compacted without reducing input limits.

Verification: Flutter analysis, full widget suite, release build and exact outcomes are in verification-results.md. New responsive tests cover all four screens at 320/390/960/1440px, real bundled text/icon fonts, draft retention across transitions, larger Today text and reduced motion. Visual previews use synthetic data and are ignored local artifacts, not live-account verification. Backend and database behavior were not changed in this batch; existing AI quota/native/service gates remain.

Final UI verification: **25 Flutter tests passed**, analysis had no issues, release web build passed in **38.4s**. The local web page and both fonts/licenses returned HTTP 200. Final responsive previews cover 320, 390, 960 and 1440px. Backend/API/worker were not restarted or modified; the existing static server serves the rebuilt app at http://127.0.0.1:8080. Hard refresh to replace a cached bundle.
