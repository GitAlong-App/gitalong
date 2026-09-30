"""
GitAlong FastAPI Application
"""
import logging
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from .api.v1 import api_router
from .config import get_settings
from .core.rate_limit import SlidingWindowLimiter

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)
settings = get_settings()

# Unauthenticated / per-connection ceiling. Authenticated users are also
# limited per user id inside verify_token (see core/rate_limit.py).
_ip_limiter = SlidingWindowLimiter(max_requests=max(settings.rate_limit_per_minute * 3, 60), window_seconds=60)


def _client_ip(request: Request) -> str:
    # Render (and most PaaS) terminate TLS at a proxy that appends the real
    # client address to X-Forwarded-For. The right-most entry is the one the
    # proxy wrote; left-most entries are client-controlled.
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[-1].strip()
    return request.client.host if request.client else "unknown"


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method != "OPTIONS" and not _ip_limiter.hit(_client_ip(request)):
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Please slow down."},
                headers={"Retry-After": "60"},
            )
        return await call_next(request)


class CatchErrorsMiddleware(BaseHTTPMiddleware):
    """
    Converts unhandled exceptions into a generic 500 *inside* the CORS layer so
    browsers still receive CORS headers (Starlette's default error handler sits
    outside CORSMiddleware). Internal details are logged, never returned.
    """

    async def dispatch(self, request: Request, call_next):
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            logger.exception("Unhandled error on %s %s", request.method, request.url.path)
            response = JSONResponse(status_code=500, content={"detail": "Internal server error."})
        elapsed_ms = (time.perf_counter() - started) * 1000
        if elapsed_ms > 1500:
            logger.warning("Slow request %s %s took %.0f ms", request.method, request.url.path, elapsed_ms)
        return response


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=(
        "GitAlong backend: intent-aware collaborator matching for developers, "
        "ranked on verified GitHub activity."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
)

# Order matters: the last middleware added is the outermost.
app.add_middleware(CatchErrorsMiddleware)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    max_age=600,
)

app.include_router(api_router)


@app.get("/", tags=["root"])
async def root():
    return {"name": settings.app_name, "version": settings.app_version, "docs": "/docs"}


logger.info(
    "GitAlong API %s starting (ml_ranking=%s, origins=%s)",
    settings.app_version,
    settings.ml_ranking_enabled,
    settings.allowed_origins,
)
