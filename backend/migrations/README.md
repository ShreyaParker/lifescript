# Migration sequence

Review against an isolated development project before applying. These files are not automatically run at app startup. Existing schemas require reconciliation; migration 0001 deliberately replaces legacy `users` policies and changes client grants.

| Order | Purpose |
| --- | --- |
| 0001 | Core tables, auth-profile bootstrap, owner-only profile reads, backend-only domain writes |
| 0002 | Atomic entries/runs, leased claims, approval commits, vector/full-text memory, assets and scheduling |
| 0003 | Durable delayed storage/checkpoint deletion |
| 0004 | Separate calendar consent, encrypted-token metadata and approved actions |
| 0005 | Versioned source correction and conditional memory indexing |
| 0006 | Private checkpoint schema and account-delete cleanup references |
| 0007 | Ten-per-hour legacy inline model quota |
| 0008 | Twenty-rule account limit, transactional pause/cancellation, quota-aware scheduling |
| 0009 | Fifty-file / 100 MiB owner storage limit |
| 0010 | Unused upload removal, seven-day orphan cleanup and schema-version metadata |
| 0011 | Pending/ready upload state and schema version 11 |
| 0012 | Owner-enforced goals/projects, onboarding-goal backfill/sync and task links |

All files assume Supabase's `auth`, `storage`, `extensions`, `anon`, `authenticated`, and `service_role` infrastructure. The disposable PostgreSQL integration fixture supplies minimal substitutes and pgvector for transaction/policy tests. It does not reproduce every hosted Supabase behavior.

Apply all twelve files in order. API readiness and worker startup require schema version 12; that marker is not a substitute for integration testing. Run the two-account auth/RLS, atomic replay, source correction/deletion and scheduled-action tests before real data.

The old `backend/supabase_migrations.sql` is historical prototype SQL and is not part of this sequence. On 23 October 2026, the selected development project was audited at version 11 and only additive migration 0012 was applied transactionally; a subsequent audit reported version 12. Do not replay the baseline on that project.
