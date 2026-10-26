import logging
import time
from uuid import uuid4
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.logging import configure_logging
from app.core.body_limit import BodySizeLimit
from app.routers import onboarding, journal, tasks, profile, canvas, workflows, calendar, objectives, assistant

log = logging.getLogger("lifescript.api")
configure_logging()
app = FastAPI(title="LifeScript API", version="0.2.0")
app.add_middleware(BodySizeLimit, max_bytes=settings.MAX_UPLOAD_BYTES+1048576)

@app.middleware("http")
async def request_context(request: Request, call_next):
    started = time.monotonic()
    request.state.request_id = str(uuid4())
    try:
        length = int(request.headers.get("content-length", "0"))
    except ValueError:
        return JSONResponse(status_code=400, content={"detail": "Invalid content length"})
    if length > settings.MAX_UPLOAD_BYTES + 1048576:
        return JSONResponse(status_code=413, content={"detail": "Request is too large"})
    response = await call_next(request)
    log.info("request_completed", extra={"request_id": request.state.request_id,
        "status": response.status_code, "duration_ms": round((time.monotonic()-started)*1000)})
    response.headers["X-Request-ID"] = request.state.request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", str(uuid4()))
    # Exception text/tracebacks may include diary/provider credentials: omit them.
    log.error("request_failed", extra={"request_id": request_id, "exception_type": type(exc).__name__})
    return JSONResponse(status_code=500, content={"detail": "Request could not be completed", "code": "internal_error", "request_id": request_id})

app.add_middleware(CORSMiddleware, allow_origins=settings.CORS_ORIGINS,
                   allow_credentials=True, allow_methods=["GET","POST","PATCH","DELETE"], allow_headers=["Authorization","Content-Type","Idempotency-Key"])
for route, prefix in [(onboarding.router,"/onboarding"),(journal.router,"/journal"),
                      (tasks.router,"/tasks"),(profile.router,"/profile"),(canvas.router,"/canvas"),
                      (workflows.router,"/v1")]:
    app.include_router(route, prefix=prefix)
app.include_router(calendar.router, prefix="/v1/calendar")
app.include_router(objectives.router, prefix="/v1/objectives")
app.include_router(assistant.router, prefix="/v1/assistant")

@app.get("/")
def root():
    return {"message": "LifeScript API is running", "version": "0.2.0"}

@app.get("/health/live")
def live():
    return {"status": "ok"}

@app.get("/health/ready")
def ready():
    from app.core.db import get_db
    from fastapi import HTTPException
    try:
        rows=get_db().table("app_schema_metadata").select("version").eq("singleton",True).limit(1).execute().data
        if not rows or rows[0]["version"]<12:
            raise RuntimeError("schema_version_mismatch")
    except Exception:
        raise HTTPException(503,"Required database schema is unavailable") from None
    return {"status": "ready"}
