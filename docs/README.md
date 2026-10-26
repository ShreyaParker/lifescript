# LifeScript engineering documentation

**Implementation has started.** Read [implementation progress](implementation-progress.md), [current implementation](current-implementation.md), [verification results](verification-results.md), and the [updated runbook](implementation-runbook.md) first. The original audit documents below describe the pre-implementation baseline; they are retained to explain the changes and issue IDs.

Codebase review date: **22 October 2026**. This documentation describes the local source tree reviewed on that date, rather than a verified deployed environment.

LifeScript is a Flutter journaling and planning prototype backed by FastAPI, Supabase Auth/PostgreSQL, and Google's Gemini API. It already generates structured tasks and coaching reflections. Its main engineering challenge is connecting those capabilities to the current UI through a consistent, authenticated, recoverable data flow.

## Reading guide

| Document | Purpose |
| --- | --- |
| [Implementation progress](implementation-progress.md) | Current milestone status, fixed issue IDs, pending service gates and next priorities |
| [Current implementation](current-implementation.md) | Updated architecture, user journey, active modules, API routes and limitations |
| [Implementation runbook](implementation-runbook.md) | Current setup, ordered migrations, workers, models, calendar, tests and containers |
| [Verification results](verification-results.md) | Exact local check results and explicitly unverified services |
| [Architecture](architecture.md) | Current components, boundaries, diagrams, execution flows, and feature maturity |
| [Backend](backend.md) | Python modules, dependencies, services, configuration, and runtime behavior |
| [Frontend](frontend.md) | Flutter navigation, state, screens, design system, caching, and platform concerns |
| [API reference](api-reference.md) | Every registered application endpoint, payloads, response shapes, and contract gaps |
| [Database](database.md) | Tables, known versus inferred schema, migration gaps, ownership, and retrieval design |
| [AI engineering](ai-engineering.md) | Existing prompts and model calls; proposed extraction, planning, memory, and approval workflow |
| [Risks and technical debt](risks-and-technical-debt.md) | Source-backed findings ordered by impact, with concrete remediation and verification |
| [Development and operations](development-and-operations.md) | Local setup, environment variables, commands, deployment preparation, and troubleshooting |
| [Testing and evaluation](testing-and-evaluation.md) | Existing test limitations, safe verification, proposed regression cases, and AI evaluation gates |
| [Target system design](target-system-design.md) | Proposed modular architecture, durable jobs, transactions, idempotency, capacity, and observability |
| [Upgrade roadmap](upgrade-roadmap.md) | Sequenced implementation work, acceptance criteria, and portfolio milestones |
| [Multimodal agent implementation plan](multimodal-agent-implementation-plan.md) | Expanded plan for voice, vision, documents, LangGraph, personal RAG, and authorized automation |
| [Free AI tools](free-ai-tools.md) | Verified primary references, practical free/local options, limitations, and adoption order |
| [Source inventory](source-inventory.md) | File-level coverage map and boundaries of this scan |

Start with architecture, risks, and the roadmap. Use the API and database documents while implementing the first milestone.

## Evidence and interpretation

- **Current** means visible in the checked source; it does not mean the feature was successfully exercised against a live service.
- **Inferred** means required by application queries but not fully defined by the repository's SQL.
- **Proposed** means a future design. No proposed route, table, agent workflow, container, or CI pipeline was implemented by this documentation task.
- Backend application source: 24 Python files, 618 lines including empty package files. Frontend application source: 23 Dart files, 2,630 lines. Generated caches, installed dependencies, and binary assets are outside those counts.
- The pasted proposal supplies product direction. Its Firestore assumption does not match this repository: persistence here is Supabase. NLP extraction here uses Gemini rather than a separate traditional NLP pipeline.
- No credentials were copied into these docs, no live database was queried or migrated, and no hosted model requests were made. Exact deployed schema, RLS policies, provider quota, and operational health remain unverified.

The audit identifies deployment blockers; it does not establish that the application is production ready. See [verification details](testing-and-evaluation.md).
