import hmac
import logging

from fastapi import APIRouter, Header, HTTPException, status

from ...config import get_settings
from ...database import get_supabase_client
from ...services.ml_trainer import MlTrainer

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])


def _require_admin(secret: str) -> None:
    configured = get_settings().admin_retrain_secret
    if not configured:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Admin secret not configured.")
    if not hmac.compare_digest(secret.encode(), configured.encode()):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized.")


@router.post("/retrain-ml", status_code=status.HTTP_200_OK)
async def retrain_ml(x_admin_secret: str = Header(default="")):
    """Retrain the logistic-regression ranker and persist weights to Supabase."""
    _require_admin(x_admin_secret)
    try:
        result = MlTrainer(model_name=get_settings().ml_model_name).retrain()
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("ML retrain failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Retrain failed; see server logs."
        ) from exc

    return {
        "status": "ok",
        "model_name": result.model_name,
        "version": result.version,
        "trained_at": result.trained_at,
        "rows": result.n_rows,
        "positives": result.n_pos,
        "auc": result.auc,
        "features": result.feature_names,
    }


@router.get("/metrics")
async def product_metrics(x_admin_secret: str = Header(default="")):
    """Last 30 days of funnel metrics (see supabase/migrations/*_product_metrics.sql)."""
    _require_admin(x_admin_secret)
    rows = get_supabase_client().table("admin_daily_metrics").select("*").execute().data or []
    totals = {
        key: sum(int(r.get(key) or 0) for r in rows)
        for key in ("signups", "swipes", "likes", "matches", "messages", "qualified_conversations")
    }
    totals["match_rate"] = round(totals["matches"] / totals["likes"], 4) if totals["likes"] else None
    totals["conversation_rate"] = (
        round(totals["qualified_conversations"] / totals["matches"], 4) if totals["matches"] else None
    )
    return {"window_days": 30, "totals": totals, "daily": rows}
