import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status

from ...core.auth import verify_token
from ...models.recommendation import RecommendationResponse
from ...services.recommendation_service import ProfileNotFoundError, RecommendationService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("", response_model=RecommendationResponse)
async def get_recommendations(
    limit: int = Query(default=20, ge=1, le=100, description="Number of profiles to return"),
    languages: list[str] | None = Query(default=None, description="Filter by languages (any match)"),
    interests: list[str] | None = Query(default=None, description="Filter by interests/topics (any match)"),
    looking_for: list[str] | None = Query(default=None, description="Collaboration intents you want to match"),
    location: str | None = Query(default=None, description="Filter by location (substring match)"),
    min_followers: int | None = Query(default=None, ge=0),
    min_public_repos: int | None = Query(default=None, ge=0),
    active_within_days: int | None = Query(default=None, ge=1, le=3650),
    filter_mode: Literal["soft", "strict"] = Query(default="soft"),
    user_id: str = Depends(verify_token),
) -> RecommendationResponse:
    """
    Personalised collaborator recommendations, best first. Each item carries a
    0–100 `match_score`, a `score_breakdown` and human-readable `match_reasons`.
    """
    try:
        return await RecommendationService().get_recommendations(
            user_id=user_id,
            limit=limit,
            filters={
                "languages": languages or [],
                "interests": interests or [],
                "looking_for": looking_for or [],
                "location": (location or "").strip() or None,
                "min_followers": min_followers,
                "min_public_repos": min_public_repos,
                "active_within_days": active_within_days,
                "filter_mode": filter_mode,
            },
        )
    except ProfileNotFoundError as exc:
        # Only this case is a 404. Any other ValueError (pydantic's
        # ValidationError is one) is a server fault and must not be turned
        # into a "not found" that echoes internal data back to the client.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
