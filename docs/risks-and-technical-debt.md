# Risks and technical debt register

> Baseline audit snapshot, before the implementation changes. See [current implementation](current-implementation.md), [progress tracker](implementation-progress.md), and [verification results](verification-results.md) for the updated state.

This is a source review, not a penetration test or confirmation of live exploitability. Severity reflects potential impact in this implementation. Deployed key privileges, RLS, schema, and network exposure were not inspected.

## P0: close before exposing real user data

| ID | Finding and evidence | Fix | Required verification |
| --- | --- | --- | --- |
| R01 | `core/security.py:get_current_user` returns zero UUID when bearer is missing | Require authentication; isolate any demo mode behind nonproduction configuration and synthetic data | Missing/malformed/expired tokens fail; demo disabled in deployment |
| R02 | `routers/onboarding.py:setup_deeper_profile` accepts arbitrary body user ID without auth | Derive ID from auth, remove caller-controlled owner field | User A cannot modify user B; current user's onboarding flag persists |
| R03 | `routers/tasks.py:toggle_task_status` updates by ID alone | Filter by task ID and authenticated owner, return deliberate 404/403 | Known foreign task ID cannot be changed |
| R04 | Privileged-looking backend key plus no checked RLS/base-schema migration | Reconcile permissions, implement RLS for direct client access and backend ownership filters | Fresh-database policy tests with separate accounts/roles |

## P1: repair core correctness and trust

| ID | Finding and evidence | Fix / acceptance check |
| --- | --- | --- |
| R05 | Frontend onboarding submits zero UUID; login/splash read signed-in user's profile | Use authenticated API client; restart after onboarding still reaches shell |
| R06 | Onboarding catches write errors and returns success | Return truthful error; simulated DB failure keeps user on retryable onboarding state |
| R07 | Frontend `TaskNotifier.fetchDailyTasks` calls missing GET `/tasks` | Add typed owner-scoped list endpoint; pending tasks reload after app restart |
| R08 | Journal returns pre-insert task payloads, omitting IDs | Return persisted records; response IDs can be toggled/reloaded |
| R09 | Router opens shell, not `DashboardScreen`; Nexus/Gallery have independent singletons | Choose canonical task/media repositories and wire current tabs; submission appears in Nexus |
| R10 | Journal pipeline writes separately, with no operation identity | Save journal independently; transactional proposal/task commit and idempotency; injected failure/retry does not duplicate or lose work |
| R11 | Gemini/Supabase synchronous calls run inside async handlers | Async adapters or controlled offload; bounded jobs; concurrent ordinary requests stay responsive during model delay |
| R12 | Shell “Sign Out” only navigates; caches/providers/singletons not reset | Single auth/session cleanup flow; account B sees none of A's prior local state |
| R13 | `canvas.py` is unauthenticated and accepts arbitrary body / server-funded model calls | Auth, input bounds, quotas, rate limiting; unauthenticated requests cannot consume model capacity |
| R14 | Raw exception details returned by routers/global handler; unstructured local traceback log | Sanitize errors, redact logs, add request IDs; simulated provider/DB exceptions reveal no tokens or private text |
| R15 | Tasks/audits use fixed goals despite profile persistence | Read actual owner goals and version snapshot; changing goal changes workflow input |
| R16 | Canvas mutates local tasks/media and displays canned success before HTTP result | Preserve draft, show pending state, commit canonical updates only after confirmation; failure leaves no false completion |
| R17 | Static Resonance scores and Gallery mental-state correlations presented as analysis | Remove or label synthetic demo data; computed metrics require defined source/method and sufficient samples |
| R18 | SQL only alters absent base tables; no reproducible provisioning | Ordered complete migrations; empty-database setup and rollback/restore rehearsal succeed |
| R19 | “Tests” can execute real API/DB/model operations at import/collection | Move manual probes, main-guard scripts, use fakes and isolated fixtures; default pytest has no network/writes |
| R20 | Free-tier remote inference receives raw journal/profile context | Use synthetic data for unpaid remote experiments; choose local processing or an explicitly reviewed deployment data policy |

## P2: hardening and maintainability

| ID | Finding and evidence | Next action |
| --- | --- | --- |
| R21 | Multiple hardcoded loopback Dio clients; unused shared ApiClient | Shared environment config, auth interceptor, timeouts and error translation |
| R22 | Stored embeddings have no retrieval/version contract | Validate dimension and introduce owner-scoped retrieval only with evaluation evidence |
| R23 | Audit reads seven entries, newest-first, rather than a week; no task progress | Define review window/timezone, chronological ordering, evidence links, cached/persisted audit |
| R24 | Archive concatenates an unchecked date and ends at `23:59:59Z` | Typed date, half-open timezone-aware interval and pagination |
| R25 | Placeholder-email upserts can replace identity email | Dedicated profile bootstrap preserving verified email; idempotent user creation |
| R26 | Schemas lack lengths, enums, task count/XP constraints, and deadline semantics | Shared typed contracts with domain validation and boundary cases |
| R27 | Task toggles mutate shared objects; multiple rapid toggles can race | Immutable entities and serialized/version-aware updates with tested rollback |
| R28 | Hive cache is written only after network success, unscoped and not encrypted in app code | Honest cache semantics first; later account-scoped draft/outbox with conflict and retention policy |
| R29 | Android release debug signing, missing main INTERNET permission, local OAuth callback | Release configuration and real target-device auth/network smoke checks |
| R30 | Unpinned Python dependencies, template Flutter test, no CI/container setup | Lock dependencies, replace template test, add deterministic CI and build verification |
| R31 | Canvas key reads process env instead of Settings; BYOK client unused | One provider config path; either implement secure full BYOK flow or remove dormant UI claims |
| R32 | `.gitignore` misses nested `__pycache__`, alternative env dirs and local error logs | Audit tracked/untracked content before initial commit; add suitable recursive exclusions |
| R33 | Camera, voice, image analysis and chat onboarding are disconnected experiments | Hide incomplete controls or deliver one explicit feature with permission/error states |

## Suggested issue grouping

Create four initial reviewable changes: (1) authentication/ownership and truthful onboarding, (2) task contract plus canonical Nexus state, (3) reproducible schema plus safe tests, (4) recoverable journal/proposal workflow. Keep product/UI experimentation separate from the first security/correctness fixes. See [roadmap acceptance criteria](upgrade-roadmap.md).
