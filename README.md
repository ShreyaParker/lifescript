# LifeScript

Write a journal entry, review suggested tasks, and turn them into progress toward goals and projects. Ask a personal assistant questions about saved context with source quotations.

The Flutter app has four daily destinations: **Today, Journal, Goals and Assistant**. FastAPI and Supabase/PostgreSQL provide authenticated persistence; a separate LangGraph worker handles intent classification, clarification, review and atomic task commits. Personal retrieval combines pgvector embeddings with full-text search. The assistant follows a read-only retrieval-and-answer graph with validated citations.

- [Setup and operations](docs/implementation-runbook.md)
- [Free Render/Vercel deployment and signed Android APK](docs/free-deployment.md)
- [Current architecture and APIs](docs/current-implementation.md)
- [Executed checks and service limitations](docs/verification-results.md)
- [Progress tracker](docs/implementation-progress.md)
- [Portfolio demo and r?sum? bullets](docs/resume-demo.md)

The app requires ordered migrations **0001?0012** and **both API and worker processes**. The selected development database was audited and upgraded to schema 12 on 23 October 2026. Production deployment, native-device validation and broad model-quality evaluation remain separate release gates.

From the repository root, safe isolated backend checks are `backend/venv/Scripts/python.exe -m pytest`. From `frontend`, use `flutter analyze --fatal-infos`, `flutter test` and `flutter build web --release`. See the runbook for service setup and opt-in real-service checks.

Never commit `.env`, SQL connection strings, service credentials, keystores, private journals, model data or checkpoints. The legacy prototype SQL and the second LifeScript project are references, not competing migration or authentication systems.

Current local verification: **60 backend tests passed (10 disposable-Postgres cases skipped), 25 Flutter tests passed, analysis and release web build passed**. Development API/database readiness and the worker are healthy. Gemini generation is currently quota-limited; see the verification log for the distinction between live database checks, fixture generation and actual model calls.
