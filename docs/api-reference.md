# Current API reference

> Baseline audit snapshot, before the implementation changes. See [current implementation](current-implementation.md), [progress tracker](implementation-progress.md), and [verification results](verification-results.md) for the updated state.

Base URL in Flutter: `http://127.0.0.1:8000`. No API version prefix. All JSON examples here use synthetic content. FastAPI normally provides `/docs`, `/redoc`, and `/openapi.json` in addition to the application routes below.

## Authentication and errors

Where **dependency** appears below, supply `Authorization: Bearer <Supabase access token>`. Current behavior accepts a missing token as the zero UUID; this is a defect, not an intended integration contract. An invalid supplied token produces 401. Onboarding and Canvas have no authentication dependency.

Pydantic body validation normally returns 422. Most router failures return `{"detail":"..."}` with 500 and raw exception text. Unhandled exceptions return `{"message":"Internal server error: ..."}` through the global handler. Error formats are inconsistent. Success status is normally 200, including inserts; no route explicitly selects 201/202.

## Endpoint catalog

| Method | Path | Authentication | Current behavior |
| --- | --- | --- | --- |
| GET | `/` | None | `{"message":"LifeScript API is running"}`; not a dependency health check |
| POST | `/onboarding/setup` | None | Upserts requested user's profile; false success possible |
| POST | `/journal/submit` | Dependency | Embeds journal, writes it, generates and inserts tasks |
| GET | `/journal/audit` | Dependency | Latest seven entries; model only when at least three exist |
| PATCH | `/tasks/{task_id}/toggle` | Dependency | Sets pending/completed; missing ownership predicate |
| GET | `/tasks/archive?date=YYYY-MM-DD` | Dependency | Tasks created during a UTC calendar date |
| GET | `/profile/` | Dependency | `profile` and `media` result |
| POST | `/profile/goals` | Dependency | Replaces entire macro-goal array |
| POST | `/profile/media` | Dependency | Inserts a media item |
| POST | `/canvas/parse` | None | Model extraction only; no persistence |

## Onboarding setup

```json
{
  "user_id": "00000000-0000-0000-0000-000000000000",
  "inner_landscape": "Difficulty getting started",
  "subconscious_rhythm": "Evening focus",
  "intellectual_footprint": "Technical reading",
  "core_north_star": "Build a useful portfolio project"
}
```

All five fields are required strings; UUID syntax is not validated. Writes `onboarding_complete`, `primary_north_star`, and a four-field `archetype_data` object. Success returns `status` and `message`; caught errors also return `status: success` with `developer_note`. The future authenticated contract should derive the ID and report persistence failures truthfully.

## Journal submit

Request: `{"content":"I want to spend 20 minutes reviewing Python tomorrow."}`. `content` is a required unconstrained string.

Current response shape:

```json
{
  "status": "success",
  "entry_id": "database-generated-entry-id",
  "coaching_insight": "A small review session is a manageable next step.",
  "generated_tasks": [
    {
      "user_id": "authenticated-user-id",
      "title": "Review Python notes for 20 minutes",
      "description": "Support your learning goal",
      "xp_value": 20,
      "status": "pending",
      "source": "scriptwriter"
    }
  ]
}
```

Task titles/count/content vary by model. The response returns constructed task dictionaries, not inserted database rows, so it omits task IDs and created timestamps. It also has no deadline, confidence, source entry, evidence, approval, or operation ID. Writes are not atomic and retries are not idempotent.

## Journal audit

No request body. Response has required `pattern_detected: boolean`, `coaching_message: string`, and nullable `suggested_adjustment`, which contains string `action` and `detail`.

```json
{
  "pattern_detected": false,
  "coaching_message": "Gathering more data scripts. Keep journaling daily to unlock automated weekly auditing insights!",
  "suggested_adjustment": null
}
```

The example is the fewer-than-three-entries fallback. Calling this GET with sufficient history incurs a generation call each time; no cache or persisted audit exists. Results are advisory, not executable commands.

## Tasks

PATCH body: `{"is_completed":true}`. Response: `{"status":"success","task_id":"...","new_status":"completed"}`. False sets `pending`. The ID is an unconstrained string. The database update filters only by task ID, even though user ID is resolved. A missing task raises a 404 internally that the broad catch converts to 500.

Archive accepts a required string `date`. It concatenates `T00:00:00Z` / `T23:59:59Z` and filters `user_id` and `created_at`; it returns a raw array of database rows. It is a creation-date view, not a completion-history view. There is no typed date validation, timezone selection, pagination, or inclusive subsecond end-of-day handling. Prefer a validated local date converted to a half-open UTC interval `[start, next_start)`.

## Profile and media

GET `/profile/` returns:

```json
{
  "profile": {"archetype_data": {}, "macro_goals": ["Learn Python"]},
  "media": []
}
```

Only those two user columns are selected. With no matching user, the current `maybe_single()` result may yield `profile: null`; client code normalizes null to an empty map. Media are raw `user_media` rows ordered by `updated_at` descending.

POST `/profile/goals` takes `{"goals":["Learn Python"]}` and returns `{"status":"success"}`. It upserts a placeholder user/email before replacing goals. There is no append semantics, conflict version, count limit, or duplicate validation.

POST `/profile/media` takes `{"media_type":"book","title":"Example Book","current_status":"reading"}` and returns success. The default status is `completed`; type and status are plain strings without enumerated validation. No inserted row ID is returned.

## Canvas parse

Body is an arbitrary object; only `text` is read. Optional `X-Gemini-Key` overrides `os.getenv("GEMINI_API_KEY")`. Response fields are string arrays `detected_books`, `detected_movies`, `detected_hobbies`. It uses Gemini schema output and does not save detected media. The current Flutter Canvas does not call this endpoint.

## Contract gaps to resolve first

1. Implement `GET /tasks`: the frontend requests it but no such handler exists.
2. Return typed persisted task rows with stable IDs from journal submission.
3. Authenticate onboarding/Canvas and scope every entity update by the current user.
4. Read actual profile goals in agents instead of fixed arrays.
5. Define a shared error envelope, input bounds, pagination, date/time semantics, and API versioning.

The [target system design](target-system-design.md) proposes a separate draft/run/approval contract. Those endpoints are not available today.
