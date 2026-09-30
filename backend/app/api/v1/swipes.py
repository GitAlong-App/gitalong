"""
Swipes API
==========
POST /api/v1/swipes          — Record (or change) a swipe. Matches are created
                                by the database trigger when a like is mutual.
GET  /api/v1/swipes/history  — The caller's recent swipes.
"""
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from postgrest.exceptions import APIError
from pydantic import BaseModel, field_validator

from ...core.auth import verify_token
from ...repositories.match_repository import MatchRepository
from ...repositories.swipe_repository import SwipeRepository

router = APIRouter(prefix="/swipes", tags=["swipes"])

_FOREIGN_KEY_VIOLATION = "23503"


class SwipeRequest(BaseModel):
    swiped_user_id: str
    action: Literal["like", "dislike", "superLike"]

    @field_validator("swiped_user_id")
    @classmethod
    def canonical_uuid(cls, v: str) -> str:
        # Canonical lower-case form: the self-swipe check and the pair_key
        # lookup below compare strings, and Postgres prints uuids lower-case.
        try:
            return str(UUID(v))
        except ValueError:
            raise ValueError("swiped_user_id must be a UUID.") from None


class SwipeResponse(BaseModel):
    status: str
    matched: bool = False
    match_id: str | None = None


class SwipeHistoryItem(BaseModel):
    id: str
    swiped_user_id: str
    action: str
    swiped_at: str


@router.post("", response_model=SwipeResponse, status_code=status.HTTP_201_CREATED)
async def record_swipe(body: SwipeRequest, user_id: str = Depends(verify_token)):
    if body.swiped_user_id == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot swipe on yourself.")

    try:
        SwipeRepository().upsert_swipe(user_id, body.swiped_user_id, body.action)
    except APIError as exc:
        if exc.code == _FOREIGN_KEY_VIOLATION:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.") from exc
        raise

    if body.action == "dislike":
        return SwipeResponse(status="ok")
    match = MatchRepository().get_match_between(user_id, body.swiped_user_id)
    return SwipeResponse(status="ok", matched=match is not None, match_id=str(match["id"]) if match else None)


@router.get("/history", response_model=list[SwipeHistoryItem])
async def get_swipe_history(
    limit: int = Query(default=50, ge=1, le=200),
    user_id: str = Depends(verify_token),
):
    rows = SwipeRepository().get_swipe_history(user_id, limit)
    return [
        SwipeHistoryItem(
            id=str(r["id"]), swiped_user_id=r["swiped_user_id"], action=r["action"], swiped_at=str(r["swiped_at"])
        )
        for r in rows
    ]
