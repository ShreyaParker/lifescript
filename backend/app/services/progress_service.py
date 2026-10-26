from datetime import datetime, timedelta, timezone


def count(query):
    response = query.execute()
    exact = getattr(response, "count", None)
    return exact if exact is not None else len(response.data or [])


def weekly_counts(db, owner, reference=None):
    end = reference or datetime.now(timezone.utc)
    start = (end-timedelta(days=7)).isoformat()
    def tasks():
        return db.table("tasks").select("id",count="exact",head=True).eq("user_id",owner).gte("created_at",start)
    return {
        "window_start":start,
        "reflections":count(db.table("journal_entries").select("id",count="exact",head=True).eq("user_id",owner).gte("created_at",start)),
        "tasks_created":count(tasks()),
        "tasks_currently_completed":count(tasks().eq("status","completed")),
    }
