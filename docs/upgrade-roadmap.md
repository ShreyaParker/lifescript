# Upgrade roadmap

> Implementation is now underway. See [implementation progress](implementation-progress.md) and [current implementation](current-implementation.md) for completed work and remaining gates. This document retains the original design/selection context.

## Product direction

Position LifeScript as a **journal-to-plan assistant with reviewable suggestions and memory**, rather than a diagnostic mental-health system. The strongest next-level demonstration is one complete journey: a user writes a reflection, receives a source-backed small plan, edits/approves it, sees persisted tasks, and gets a truthful progress review later.

The phases below are ordered by dependency. Effort estimates are planning ranges for one developer familiar with the stack, not promises; unknown live schema and auth setup can increase the first phases.

## Phase 0: reproducible and safe baseline (roughly 2–4 focused days)

Work:

- Reconcile actual database schema and commit complete ordered migrations with synthetic seeds.
- Remove implicit auth bypass, authenticate onboarding/Canvas, and add ownership to task updates.
- Replace zero-ID onboarding with current-user context; stop reporting successful failed writes.
- Isolate destructive/manual scripts; create deterministic auth/ownership tests with fake dependencies.
- Pin backend dependencies, audit ignore patterns, and define environment configuration.

Done when a clean development environment can be created; no-token and cross-user tests fail safely; real onboarding survives restart; default tests make no external calls. Start here before adding AI frameworks.

## Phase 1: connect the actual app (roughly 3–5 days)

Work:

- Add GET tasks and return persisted task IDs from submit.
- Introduce one authenticated Dio client and typed task/profile/error models.
- Make Nexus consume canonical persisted tasks instead of a separate seeded singleton list.
- Choose one media persistence model and connect Gallery; connect actual goal changes to planning context.
- Unify real sign-out and clear/invalidate account-local state.
- Remove or visibly label simulated scores/correlations; hide voice/camera controls until functional.
- Preserve failed-submit drafts and distinguish pending updates from saved changes.

Done when sign in -> onboard -> submit -> see tasks -> toggle -> restart reload -> sign out works in the current tab interface. A second account must not see the first account's state. Core flow should have visible empty/loading/error states.

## Phase 2: reliable structured understanding (roughly 3–5 days)

Work:

- Separate saving a journal from AI enrichment; introduce run IDs and retryable status.
- Expand schemas with evidence, uncertainty, task limits, validated XP/duration, and timezone-aware dates.
- Read actual goals and pending tasks; remove fixed personal context.
- Add provider adapter, timeouts, bounded repair/retries, and concurrency limits.
- Build the 50-case synthetic benchmark and compare against the existing single-call baseline.
- Add local inference adapter only after the shared schema is stable.

Done when provider failure does not lose a journal; negation/completed-action fixtures do not create misleading tasks; benchmark results and failure counts are saved with model/prompt versions.

## Phase 3: durable planning and user review (roughly 1–2 weeks)

Work:

- Add owner-scoped run/proposal/decision tables and idempotency constraints.
- Implement extraction -> validation -> planning -> review -> atomic commit.
- Introduce LangGraph checkpoint/interrupt support if it simplifies real resume/branching needs.
- Build proposal cards with evidence, edit/reject/approve controls and clarification questions.
- Add a durable worker/lease mechanism; test crash/replay and double approval.

Done when no generated suggestion becomes a task without an explicit decision; restarting during generation/review resumes safely; repeat approval creates the same task set; stale proposals are detected.

## Phase 4: useful memory and progress review (roughly 4–7 days)

Work:

- Start with saved goals, pending tasks, and recent history; benchmark semantic retrieval before adding it.
- Add versioned owner-scoped pgvector retrieval with source IDs and deletion invalidation.
- Persist dated review results using actual task progress and correctly ordered time windows.
- Replace Resonance constants with defined observations: completed/planned task counts, user-reported energy trends, and evidence-linked narrative suggestions.
- Add memory inspection/forget/export controls.

Done when retrieved sources belong to the owner, improve measured plan relevance over recent-history-only baseline, disappear after deletion, and support the displayed review claims. Avoid interpreting correlation as causation.

## Phase 5: portfolio and deployment quality (roughly 4–7 days)

Work:

- Add reproducible containers, CI, safe migrations, health/readiness, structured logs, and optional redacted traces.
- Add account-scoped local drafts/outbox after server idempotency is proven.
- Fix mobile release networking/signing/deep links, web branding, accessibility, and responsive states.
- Record a synthetic end-to-end demo and publish measured benchmark/latency results.
- Write an architecture decision record for each substantive tradeoff and a failure-recovery runbook.

Done when CI passes on a clean checkout, a documented deployment can be recreated, backups can be restored, core failure scenarios recover, and the demo has no hidden mock-backed claims. Hosted deployment is optional for the first free local portfolio version.

## First implementation slice

Deliver this before a broad redesign:

1. Fix `get_current_user`, authenticated onboarding, and owner-scoped toggle.
2. Add safe regression fixtures for those boundaries.
3. Add owner-filtered GET `/tasks`; return inserted tasks with IDs from submit.
4. Replace Nexus demo tasks with the real task repository.
5. Verify with two synthetic accounts, a failed write, a failed model call, and a restart.

This slice resolves the largest gap between demonstrated AI generation and visible persistent user value. It creates a sound foundation for the later proposal workflow without requiring LangGraph immediately.

## What to defer

Defer autonomous calendar/email actions, image-based psychological analysis, fine-tuning, graph databases, a vector-store migration, multi-agent debate loops, and microservice decomposition. Revisit a feature only when a user need and an evaluation case justify its complexity. Voice transcription can follow the text workflow, reusing the same journal/proposal contracts.

## Portfolio evidence to produce

Keep an architecture diagram, reproducible setup, safe demo dataset, benchmark report, replay/authorization tests, and a short video showing both success and failure recovery. Resume claims should describe implemented and measured behavior only. “Durable human-reviewed planning with owner-scoped retrieval and replay-safe task persistence” becomes credible after those mechanisms exist and pass checks.
