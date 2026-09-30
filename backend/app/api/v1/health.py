import logging

from fastapi import APIRouter

from ...database import get_supabase_client

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/health", tags=["health"])
async def health_check():
    """Liveness + database reachability. Never returns internal error details."""
    try:
        get_supabase_client().table("ml_model_params").select("model_name").limit(1).execute()
        return {"status": "ok", "service": "GitAlong API", "database": "connected"}
    except Exception:
        logger.exception("Health check DB probe failed")
        return {"status": "degraded", "service": "GitAlong API", "database": "unavailable"}
