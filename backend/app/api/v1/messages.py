"""
Messages API
=============
GET  /api/v1/matches/{match_id}/messages       — Messages in a match (newest first).
POST /api/v1/matches/{match_id}/messages       — Send a message.
PUT  /api/v1/matches/{match_id}/messages/read  — Mark received messages read.
"""
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, field_validator

from ...core.auth import verify_token
from ...database import get_supabase_client
from ...repositories.match_repository import MatchRepository
from ...repositories.message_repository import MessageRepository
from ._validation import timestamp_cursor
from .matches import _require_member

router = APIRouter(prefix="/matches", tags=["messages"])

MAX_MESSAGE_LENGTH = 4000


class MessageOut(BaseModel):
    id: str
    match_id: str
    sender_id: str
    receiver_id: str
    content: str
    type: str = "text"
    sent_at: str
    is_read: bool = False


class MessageListResponse(BaseModel):
    messages: list[MessageOut]
    count: int


class SendMessageRequest(BaseModel):
    receiver_id: str
    content: str
    type: Literal["text", "link", "code"] = "text"

    @field_validator("content")
    @classmethod
    def validate_content(cls, v: str) -> str:
        # Stored verbatim, as on the direct Supabase path: developers send code
        # like `Vec<String>` and indented snippets, and clients render plain
        # text, so nothing is sanitised or trimmed (trimming ate the first
        # line's indentation of code messages).
        if not v.strip():
            raise ValueError("Message content cannot be empty.")
        if len(v) > MAX_MESSAGE_LENGTH:
            raise ValueError(f"Message too long (max {MAX_MESSAGE_LENGTH} characters).")
        return v


class SendMessageResponse(BaseModel):
    message: MessageOut
    status: str = "sent"


def _to_out(row: dict) -> MessageOut:
    return MessageOut(
        id=str(row["id"]),
        match_id=str(row["match_id"]),
        sender_id=row["sender_id"],
        receiver_id=row["receiver_id"],
        content=row["content"],
        type=row.get("type") or "text",
        sent_at=str(row.get("sent_at", "")),
        is_read=bool(row.get("is_read", False)),
    )


def _is_blocked(user_a: str, user_b: str) -> bool:
    resp = (
        get_supabase_client()
        .table("blocks")
        .select("blocker_id")
        .or_(f"and(blocker_id.eq.{user_a},blocked_id.eq.{user_b}),and(blocker_id.eq.{user_b},blocked_id.eq.{user_a})")
        .limit(1)
        .execute()
    )
    return bool(resp.data)


@router.get("/{match_id}/messages", response_model=MessageListResponse)
async def get_messages(
    match_id: str,
    limit: int = Query(default=50, ge=1, le=200),
    before: str | None = Query(default=None, description="ISO timestamp cursor (sent_at)"),
    user_id: str = Depends(verify_token),
):
    cursor = timestamp_cursor(before)
    match = _require_member(match_id, user_id)
    rows = MessageRepository().get_messages(str(match["id"]), limit, cursor)
    messages = [_to_out(r) for r in rows]
    return MessageListResponse(messages=messages, count=len(messages))


@router.post("/{match_id}/messages", response_model=SendMessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(match_id: str, body: SendMessageRequest, user_id: str = Depends(verify_token)):
    match = _require_member(match_id, user_id)
    if body.receiver_id == user_id or body.receiver_id not in (match.get("users") or []):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Receiver is not the other member of this match."
        )
    if _is_blocked(user_id, body.receiver_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can't message this user.")

    row = MessageRepository().send_message(str(match["id"]), user_id, body.receiver_id, body.content, body.type)
    if not row:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Message could not be sent.")
    return SendMessageResponse(message=_to_out(row))


@router.put("/{match_id}/messages/read", status_code=status.HTTP_200_OK)
async def mark_messages_read(match_id: str, user_id: str = Depends(verify_token)):
    match_id = str(_require_member(match_id, user_id)["id"])
    count = MessageRepository().mark_as_read(match_id, user_id)
    MatchRepository().mark_read(match_id, user_id)
    return {"status": "ok", "marked_read": count}
