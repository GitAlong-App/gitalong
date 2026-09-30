"""
Matches API
===========
GET    /api/v1/matches           — The caller's matches (cursor pagination).
GET    /api/v1/matches/{id}      — One match.
DELETE /api/v1/matches/{id}      — Unmatch.
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import BaseModel

from ...core.auth import verify_token
from ...models.user import UserProfile
from ...repositories.match_repository import MatchRepository, is_unread_for
from ...repositories.swipe_repository import SwipeRepository
from ...repositories.user_repository import UserRepository
from ._validation import timestamp_cursor, uuid_or_404

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/matches", tags=["matches"])


class MatchUserSummary(BaseModel):
    id: str
    username: str
    name: str | None = None
    avatar_url: str | None = None
    bio: str | None = None
    languages: list[str] = []
    looking_for: list[str] = []
    pitch: str | None = None


class MatchResponse(BaseModel):
    id: str
    other_user: MatchUserSummary
    matched_at: str
    last_message: str | None = None
    last_message_at: str | None = None
    last_message_sender_id: str | None = None
    is_read: bool = True
    unread: bool = False


class MatchListResponse(BaseModel):
    matches: list[MatchResponse]
    count: int
    next_cursor: str | None = None
    has_more: bool = False


def _other_id(row: dict, user_id: str) -> str | None:
    return next((uid for uid in row.get("users") or [] if uid != user_id), None)


def build_match_response(row: dict, other: UserProfile, user_id: str) -> MatchResponse:
    unread = is_unread_for(row, user_id)
    return MatchResponse(
        id=str(row["id"]),
        other_user=MatchUserSummary(
            id=other.id,
            username=other.username,
            name=other.name,
            avatar_url=other.avatar_url,
            bio=other.bio,
            languages=other.languages,
            looking_for=other.looking_for,
            pitch=other.pitch,
        ),
        matched_at=str(row["matched_at"]),
        last_message=row.get("last_message"),
        last_message_at=str(row["last_message_at"]) if row.get("last_message_at") else None,
        last_message_sender_id=row.get("last_message_sender_id"),
        is_read=not unread,
        unread=unread,
    )


def _require_member(match_id: str, user_id: str) -> dict:
    match_id = uuid_or_404(match_id, "Match not found.")
    row = MatchRepository().get_match_by_id(match_id)
    if row is None or user_id not in (row.get("users") or []):
        # 404 for both: don't reveal whether someone else's match exists.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Match not found.")
    return row


@router.get("", response_model=MatchListResponse)
async def list_matches(
    limit: int = Query(default=50, ge=1, le=200),
    before: str | None = Query(default=None, description="ISO timestamp cursor (matched_at)"),
    user_id: str = Depends(verify_token),
):
    cursor = timestamp_cursor(before)
    rows = MatchRepository().get_matches_for_user(user_id, limit + 1, before=cursor)
    has_more = len(rows) > limit
    rows = rows[:limit]

    others = {u.id: u for u in UserRepository().bulk_get_by_ids([_other_id(r, user_id) for r in rows])}
    matches = [
        build_match_response(r, others[oid], user_id)
        for r in rows
        if (oid := _other_id(r, user_id)) and oid in others
    ]
    return MatchListResponse(
        matches=matches,
        count=len(matches),
        next_cursor=str(rows[-1]["matched_at"]) if has_more and rows else None,
        has_more=has_more,
    )


@router.get("/{match_id}", response_model=MatchResponse)
async def get_match(match_id: str, user_id: str = Depends(verify_token)):
    row = _require_member(match_id, user_id)
    other_id = _other_id(row, user_id)
    other = UserRepository().get_by_id(other_id) if other_id else None
    if other is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Matched user not found.")
    return build_match_response(row, other, user_id)


@router.delete("/{match_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unmatch(match_id: str, user_id: str = Depends(verify_token)):
    row = _require_member(match_id, user_id)
    # Withdraw the caller's like first, so the other person can't recreate the
    # match by re-sending theirs. (Client-side deletes get this from a database
    # trigger; it can't see who is deleting when the service role does it.)
    # If this fails the match is untouched and the client can simply retry.
    other_id = _other_id(row, user_id)
    if other_id:
        SwipeRepository().withdraw_like(user_id, other_id)
    MatchRepository().delete_match(str(row["id"]))
    logger.info("Match %s deleted by %s", row["id"], user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
