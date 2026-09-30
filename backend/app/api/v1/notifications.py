"""
Notifications API
==================
POST /api/v1/notify-match — DEPRECATED.

Match notifications are now written by the database trigger that creates the
match, with the sender's name taken from their profile. This endpoint used to
let any signed-in user insert a notification for *anyone* with arbitrary text
(a spam/phishing vector). It is kept only so older app builds don't error, and
it no longer writes anything.
"""
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from ...core.auth import verify_token

router = APIRouter(tags=["notifications"])


class NotifyMatchRequest(BaseModel):
    match_id: str
    notify_user_id: str
    matcher_name: str = ""


@router.post("/notify-match", status_code=status.HTTP_200_OK, deprecated=True)
async def notify_new_match(body: NotifyMatchRequest, user_id: str = Depends(verify_token)):
    return {"status": "ignored", "reason": "notifications are created by the database when a match forms"}
