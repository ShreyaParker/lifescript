# Free and local AI engineering toolkit

> Implementation is now underway. See [implementation progress](implementation-progress.md) and [current implementation](current-implementation.md) for completed work and remaining gates. This document retains the original design/selection context.

Primary documentation checked on **22 October 2026**. Free software, free hosted quotas, and free infrastructure are different. Model licenses, hardware needs, account eligibility, and service limits must be checked again when implementing. None of the proposed tools below was installed by this documentation task.

## Recommended adoption order

| Layer | Choice | What LifeScript gains | Cost / limitation | Adopt |
| --- | --- | --- | --- | --- |
| Existing app/API | Flutter + FastAPI + Pydantic | Keep current investment; typed client/server contracts | Current dependencies; development/hardware still cost time/resources | Now |
| Existing database | Supabase PostgreSQL/Auth | Durable entities, transactions, owner isolation | Hosted Free plan has size/usage/inactivity limits | Now |
| Local inference | Ollama with a compatible locally runnable model | Private synthetic/private-data experiments without per-call API fees | Hardware, electricity, model-specific license and quality; adapter required | After schemas/tests |
| Hosted experiment | Gemini API eligible free tier | Minimal migration from current SDK | Model/account quotas; unsuitable for sensitive unpaid-service submissions | Synthetic development only |
| Workflow | LangGraph OSS | Conditional state, checkpoint/resume, human review | Checkpointer/storage engineering; hosted platform is separate | When durable review flow exists |
| Retrieval | pgvector in existing Postgres | Semantic memory without another datastore | Index/storage/query tuning; verify extension/migrations | After baseline evaluation |
| Evaluation | pytest first; Promptfoo optionally | Repeatable schema/evidence/prompt comparisons | CLI can run locally; inference/judge calls can still cost | Start fixtures now |
| Observability | Structured logs first; self-hosted Langfuse optionally | Trace workflow stages and compare model runs | Self-host infrastructure and some add-on features have separate requirements | After workflow baseline |

## Gemini: useful for continuity, bounded by terms and quota

Google's pricing page lists free-tier access for selected models, including the currently coded Flash and embedding families at review time. Availability is not a throughput guarantee for this account. Inspect project limits before load tests, and avoid enabling paid billing accidentally when the budget is zero. See [current Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing).

The unpaid-service terms restrict submitting sensitive/personal information and describe product-improvement use and human review. Develop with synthetic diaries on that tier; do not silently send real private journals there. See [Gemini API terms](https://ai.google.dev/gemini-api/terms). This makes local inference the preferred zero-API-fee privacy-oriented experiment for this app.

Keep model identifiers in configuration rather than scattered classes. Add a startup/opt-in provider smoke test for supported model/schema/dimension combinations. Do not switch model versions without replaying the held-out evaluation cases.

## Ollama: local provider option

Ollama supports schema-shaped local responses; provide the Pydantic JSON schema and still validate returned data in application code. Its cloud interface has different capability limits, so this recommendation specifically targets local execution. See [Ollama structured outputs](https://docs.ollama.com/capabilities/structured-outputs).

Use a small instruction model that fits the available computer; benchmark task evidence/negation handling and latency before naming a default. Choose an explicitly local model tag, inspect the model card/license, and test that no cloud provider fallback occurs. This review did not inspect RAM/GPU or benchmark any model, so no hardware-fit promise is made.

For local embeddings, use a dedicated embedding model through the embedding endpoint rather than a chat model. Record the returned dimension and model identity; migrate/rebuild vectors instead of mixing Gemini/Ollama spaces. See [Ollama embeddings](https://docs.ollama.com/capabilities/embeddings).

Integration task: implement shared `generate_structured` and `embed` interfaces, provider-specific timeouts/errors, and parity fixtures. Ollama is not a drop-in environment switch for the current Google SDK calls.

## LangGraph: use for durable interaction

Use a graph for extraction, deterministic validation, bounded repair, clarification, proposal, and review. Configure durable checkpoints and owner-scoped thread mapping. Interrupt at review, then resume with validated user input; keep database effects safe on replay. See [LangGraph interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts). The graph library does not replace authorization, a transaction boundary, or a worker scheduler.

## Supabase and pgvector: keep one datastore first

At review time the hosted Free plan lists 500 MB database storage, two active projects, and pausing after a week of inactivity; those are development constraints, not a production SLA. Review the full current allowances before depending on them. See [Supabase pricing](https://supabase.com/pricing).

Use PostgreSQL for tasks, proposal decisions, job state, and vectors. pgvector can support similarity retrieval within that database; the repository still needs its own extension/schema/query migration. See [Supabase pgvector guide](https://supabase.com/docs/guides/database/extensions/pgvector). Avoid adding Qdrant/Chroma solely for résumé breadth.

## Evaluation and tracing

Start with synthetic fixtures and deterministic pytest assertions. Promptfoo provides a local open-source CLI/library for evaluating prompt/provider configurations and security cases; route it to the same application adapter or equivalent fixtures rather than duplicating production prompts. Provider calls still follow the provider's billing/privacy terms. See [Promptfoo introduction](https://www.promptfoo.dev/docs/intro/).

Langfuse can be self-hosted with Docker for LLM observability; optional licensed add-ons and infrastructure costs remain separate. Keep prompt/response capture disabled or redacted for journals. Do not self-host a substantial tracing stack before basic structured logs are useful. See [Langfuse self-hosting](https://langfuse.com/self-hosting).

## Practical zero-provider-fee development profile

Use Flutter and FastAPI locally, an isolated database with synthetic seeds, one small local instruction model plus embedding model, and pytest fixtures. Add LangGraph only with persistent review state, and add tracing when a real debugging question requires it. If the existing machine cannot meet the local model's quality/latency needs, use synthetic examples with an eligible hosted free tier or deterministic fake-provider mode; do not promise real-data cloud processing for free.

Deployment hosting, email delivery, object storage, backups, public TLS/domain operations, and distribution fees are separate decisions. An AWS free-tier assumption from the pasted proposal is not a deployment budget; verify account-specific eligibility before provisioning anything.
