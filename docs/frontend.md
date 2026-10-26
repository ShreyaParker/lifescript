# Frontend architecture and design

> Baseline audit snapshot, before the implementation changes. See [current implementation](current-implementation.md), [progress tracker](implementation-progress.md), and [verification results](verification-results.md) for the updated state.

## Framework and application structure

The frontend is Flutter/Dart with a declared Dart SDK constraint `^3.9.0` and app version `1.0.0+1`. Main packages are Riverpod 2, GoRouter 14, Dio 5, Hive/Hive Flutter, Supabase Flutter/Auth UI, Google Fonts, and intl. Generator packages are declared, but the current application has no generated provider/model files. `url_launcher` is declared without an application use found in this scan.

Directories organize screens by feature; cross-feature Riverpod state lives under `lib/state`, and Nexus/Gallery use feature-local `ChangeNotifier` singletons. Most domain data uses dynamic maps rather than immutable typed models.

## Navigation map

| URL | Widget | Notes |
| --- | --- | --- |
| `/` | `SplashScreen` | Checks current session and direct Supabase onboarding flag |
| `/login` | `LoginScreen` | Google OAuth, localhost callback, dev-bypass button |
| `/onboarding` | `InteractiveOnboardingScreen` | Four fixed questions; posts mock user UUID |
| `/journal` | `JournalEntryScreen` | Separate text-entry screen sharing journalProvider |
| `/dashboard` | `MainNavigationShell` | IndexedStack of Canvas, Nexus, Gallery, Resonance |
| `/profile` | `ProfileScreen` | API-backed goals/media; actual auth sign-out |

`DashboardScreen` is not imported by the router or shell. Its task list, date archive selector, and audit alert therefore do not appear in the normal navigation flow. `/journal` is registered but its visible entry point is in that older dashboard; add an intentional entry point if retaining it.

The guard reads the current session, but no auth-event refresh bridge is configured for GoRouter. Define how token expiry, external OAuth callback, sign-in, and sign-out trigger re-evaluation. Route guards are navigation aids, not API authorization.

## State and persistence map

| Owner | Stored state | Network / persistence |
| --- | --- | --- |
| `journalProvider` | Loading, success, error, coaching insight | POST submit, post-success Hive cache, taskProvider hydration |
| `taskProvider` | Mutable `TaskItem` list | GET missing `/tasks`, PATCH toggle, GET archive |
| `profileProvider` | Profile map, media list, errors | GET profile, POST goals/media |
| `auditProvider` | Pattern flag, message, optional adjustment | GET audit; errors are swallowed |
| `NexusState.instance` | North star, anchors, seeded habits, local injected tasks | No backend or Hive persistence |
| `GalleryState.instance` | Seeded and detected media with correlation text | No backend or Hive persistence |
| Canvas widget | Conversation, detected tags, call-overlay flag | In-memory; dispatches journal submission |
| Hive `user_profile` | Opened on startup | ApiClient reads optional Gemini key; no settings writer found |
| Hive `cached_journals` | Journal content and local timestamp | Added only after API success; no replay/list UI |
| Hive `cached_tasks` | Opened on startup | No application reads/writes found |

Nexus tasks do not subscribe to `taskProvider`. Gallery does not subscribe to profile media. Updating a backend goal does not update Nexus's north star or the hardcoded goals passed to Gemini. Choose one authoritative domain model and repository for each entity.

## Networking

Each Riverpod notifier constructs its own Dio client with `http://127.0.0.1:8000`; onboarding creates another client, and archive retrieval constructs another. Providers manually attach the current bearer token. There are no explicit shared timeouts, request IDs, retry policy, cancellation strategy, or structured error translation.

`services/api_client.dart` defines an interceptor for `X-Gemini-Key`, reading Hive. No screen/provider uses this class. The header is consumed only by `/canvas/parse`, while journal/audit always use the server key. BYOK is not a working end-to-end feature.

## Screen behavior and UX risks

- Canvas recognizes small keyword sets: generic `read` can become a Dune tag, and `art` can match unrelated words. It updates local tasks/media and displays a canned success-style reply before the server confirms the journal.
- A failed submission does not roll those local changes back. The text field is cleared before server success, making recovery inconvenient.
- The microphone opens a visual overlay; there is no recording/transcription implementation. The camera callback is empty.
- Gallery correlation claims, including anxiety and clarity percentages, are constants, not measured results. Resonance's 82% alignment and other values are also constants.
- Nexus focus switching changes only local data. Its snackbar claims prompt alignment, but backend prompts do not consume that state.
- Shell sign-out only routes to login. Profile sign-out calls Supabase Auth, but does not explicitly clear account-local singleton/provider/Hive data.
- Task JSON parsing substitutes an empty ID; optimistic toggle mutates the original object shared by shallow list copies. Use immutable records and operation/version-aware rollback to handle rapid toggles.

## Design system

`LifeScriptColors` defines lavender, mint, peach, neutral text, and canvas colors. `GlassContainer` centralizes rounded translucent surfaces using `BackdropFilter` with blur sigma 15. `main.dart` uses Material 3, a deep-purple seeded scheme, and Google Fonts Inter. Several feature screens hardcode additional colors/styles, so shared tokens cover only part of the visual language.

Preserve the calm palette while consolidating typography, spacing, radii, surfaces, and interaction states into theme extensions/components. Build reviewable proposal cards with source text, rationale, edit/reject controls, and explicit persistence status. Replace simulated metrics with a clearly marked demo mode or real, defined calculations. Add empty/error/loading states, semantic labels, keyboard navigation, large-text layouts, and narrow-screen overflow checks. Profile expensive blur layers before expanding them.

## Platform configuration

- Android uses Kotlin Gradle files, Java/Kotlin target 11, and namespace/application ID `com.lifescript.frontend`. Release currently uses debug signing.
- Android main manifest lacks INTERNET permission; only debug/profile manifests declare it. Verify release networking and put required permission in the release-merged manifest.
- OAuth callback is web-localhost-specific. Android/iOS deep-link configuration and provider callback allowlists must be verified; no app-specific OAuth intent filter / URL scheme is present in the reviewed manifests/plist.
- iOS uses a 13.0 deployment target in the Xcode project. iOS and web retain template branding (`Frontend` / `frontend`). Web theme/description/icons are mostly Flutter defaults. iOS build execution was not verified on Windows.
- Android emulator loopback differs from browser loopback. Configure API URL per environment, use `10.0.2.2` for standard Android emulator host access, and use a reachable LAN host for physical devices.

## Proposed refactor

Use `core/config`, one Riverpod-provided authenticated API client, typed entity models, domain repositories, and feature controllers. Merge Nexus's visible task board onto persisted tasks; merge Gallery onto a chosen media table; surface audit in Resonance. Keep drafts as drafts until confirmed, invalidate all account-scoped state on logout, and make server acknowledgment visible before calling an action saved. See the [roadmap](upgrade-roadmap.md) for the implementation sequence.
