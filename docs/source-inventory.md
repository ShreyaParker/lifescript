# Source inventory and audit coverage

> Baseline audit snapshot, before the implementation changes. See [current implementation](current-implementation.md), [progress tracker](implementation-progress.md), and [verification results](verification-results.md) for the updated state.

## Scope

Reviewed authored application source and supporting configuration in both backend and frontend. Counts from static enumeration: **24 backend application Python files / 618 lines**, **23 frontend Dart library files / 2,630 lines**. Existing Python probes, SQL, package manifests/lockfile, test templates, root/frontend ignore rules, editor launch/task configuration, and platform entry/build/auth-related configuration were also examined. Binary icons/splash images and generated/third-party files were inventoried rather than semantically audited.

The root working tree already contained untracked application files at the start of review. Documentation changes do not commit, reorganize, or modify those files. No AGENTS.md was found by the workspace scan.

## Backend application files

Paths in this section are relative to `backend/app`.

| File | Coverage / documentation |
| --- | --- |
| [`main.py`](../backend/app/main.py) | CORS, router mounts, root, exception handling -> architecture/backend/API |
| [`core/config.py`](../backend/app/core/config.py) | Environment aliasing/startup -> backend/development |
| [`core/db.py`](../backend/app/core/db.py) | Global Supabase client -> backend/database |
| [`core/security.py`](../backend/app/core/security.py) | Token validation/bypass -> risks/backend |
| [`routers/onboarding.py`](../backend/app/routers/onboarding.py) | Setup request/upsert/fallback -> API/risks |
| [`routers/journal.py`](../backend/app/routers/journal.py) | Journal pipeline/audit -> architecture/API/AI |
| [`routers/tasks.py`](../backend/app/routers/tasks.py) | Toggle/archive -> API/risks |
| [`routers/profile.py`](../backend/app/routers/profile.py) | Goals/media/profile -> API/database |
| [`routers/canvas.py`](../backend/app/routers/canvas.py) | Extraction/key override -> API/AI |
| [`schemas/task.py`](../backend/app/schemas/task.py) | Generated tasks and coaching -> backend/AI |
| [`schemas/audit.py`](../backend/app/schemas/audit.py) | Audit result/adjustment -> API/AI |
| [`schemas/onboarding.py`](../backend/app/schemas/onboarding.py) | Chat onboarding output -> backend/AI |
| [`agents/scriptwriter.py`](../backend/app/agents/scriptwriter.py) | Prompt/schema/call -> AI |
| [`agents/auditor.py`](../backend/app/agents/auditor.py) | Prompt/history/schema -> AI |
| [`agents/resonance.py`](../backend/app/agents/resonance.py) | Disconnected image experiment -> AI/roadmap |
| [`services/embedding_service.py`](../backend/app/services/embedding_service.py) | Model/dimension/embed -> database/AI |
| [`services/onboarding_service.py`](../backend/app/services/onboarding_service.py) | Disconnected chat experiment -> backend/AI |
| Seven `__init__.py` files | Package markers in app, agents, core, models, routers, schemas, services; no additional behavior |

Other backend files: `requirements.txt`, `supabase_migrations.sql`, eight `test_*.py` probes, and `delete_user.py`. Their behavior and risks are covered in backend, database, and testing documents. Installed `venv`, bytecode caches, and secret `.env` values are excluded. Presence of `.env` was observed; contents were not read/copied.

## Frontend Dart files

Paths relative to `frontend/lib`.

| File | Role |
| --- | --- |
| [`main.dart`](../frontend/lib/main.dart) | Hive/Supabase initialization, ProviderScope, Material theme |
| [`core/router.dart`](../frontend/lib/core/router.dart) | Auth redirect and six routes |
| [`core/theme/colors.dart`](../frontend/lib/core/theme/colors.dart) | Shared palette |
| [`services/api_client.dart`](../frontend/lib/services/api_client.dart) | Unused shared Dio/key-header wrapper |
| [`state/journal_provider.dart`](../frontend/lib/state/journal_provider.dart) | Submission/cache/coaching/task hydration |
| [`state/task_provider.dart`](../frontend/lib/state/task_provider.dart) | Task model/list/toggle/archive |
| [`state/profile_provider.dart`](../frontend/lib/state/profile_provider.dart) | Profile/goals/media API state |
| [`state/audit_provider.dart`](../frontend/lib/state/audit_provider.dart) | Audit API state |
| [`shared/widgets/glass_container.dart`](../frontend/lib/shared/widgets/glass_container.dart) | Translucent rounded blurred surface |
| [`shared/widgets/script_correction_alert.dart`](../frontend/lib/shared/widgets/script_correction_alert.dart) | Audit message/adjustment display |
| [`features/auth/screens/login_screen.dart`](../frontend/lib/features/auth/screens/login_screen.dart) | OAuth and local bypass button |
| [`features/auth/screens/splash_screen.dart`](../frontend/lib/features/auth/screens/splash_screen.dart) | Session/onboarding gate |
| [`features/onboarding/screens/interactive_onboarding_screen.dart`](../frontend/lib/features/onboarding/screens/interactive_onboarding_screen.dart) | Four-choice profile setup |
| [`features/home/screens/main_navigation_shell.dart`](../frontend/lib/features/home/screens/main_navigation_shell.dart) | Four-tab IndexedStack and menu |
| [`features/canvas/screens/canvas_screen.dart`](../frontend/lib/features/canvas/screens/canvas_screen.dart) | Local chat/keyword rules and backend submit |
| [`features/nexus/screens/nexus_screen.dart`](../frontend/lib/features/nexus/screens/nexus_screen.dart) | Local focus/task board |
| `features/nexus/state/nexus_state.dart` (removed during implementation) | Seeded habits/focus/task singleton |
| [`features/gallery/screens/gallery_screen.dart`](../frontend/lib/features/gallery/screens/gallery_screen.dart) | Filtered media grid and correlation sheet |
| `features/gallery/state/gallery_state.dart` (removed during implementation) | Seeded/detected media singleton |
| [`features/resonance/screens/resonance_screen.dart`](../frontend/lib/features/resonance/screens/resonance_screen.dart) | Static metrics cards |
| [`features/profile/screens/profile_screen.dart`](../frontend/lib/features/profile/screens/profile_screen.dart) | API goals/media UI and auth sign-out |
| [`features/journal/screens/journal_entry_screen.dart`](../frontend/lib/features/journal/screens/journal_entry_screen.dart) | Standalone reflection form |
| [`features/dashboard/screens/dashboard_screen.dart`](../frontend/lib/features/dashboard/screens/dashboard_screen.dart) | Older database-backed task/archive/audit UI, unrouted |

All above feed the frontend architecture, source-backed risk register, and roadmap. Dynamic maps and local UI styling were reviewed as part of each feature; no generated models/providers were found.

## Supporting files and platform boundary

- `frontend/pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`: dependency constraints/resolution, SDK range, lint configuration.
- `frontend/test/widget_test.dart`: stale counter template. iOS RunnerTests also retain a template test harness.
- `frontend/android`: root/app/settings Gradle Kotlin files, wrapper/properties, debug/profile/main manifests, MainActivity, resources. Release signing/network/deep-link findings are in frontend docs.
- `frontend/ios`: Runner AppDelegate, Info.plist, bridge, Xcode project/scheme/workspace, Flutter xcconfigs, storyboards, asset metadata. No macOS/iOS build was attempted.
- `frontend/web`: HTML bootstrap, OAuth client metadata, manifest and icon references. Branding/callback notes are in frontend docs.
- `.gitignore` and frontend/platform ignore files: generated/secret exclusions. Nested bytecode exclusion gap is recorded.
- `.vscode/launch.json` and `tasks.json`: local development launch/task setup; not deployment infrastructure.
- `frontend/README.md`: Flutter starter instructions rather than project architecture documentation.

## What this scan cannot prove

Source review does not prove successful live OAuth, deployed RLS, complete database constraints, valid provider credentials/quota, target-device builds, model quality, or network latency. No live database/model requests or migrations were run. The documentation distinguishes those unknowns from directly observed code defects. Static syntax and documentation-link verification results are recorded in [testing and evaluation](testing-and-evaluation.md).
