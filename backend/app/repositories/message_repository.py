from __future__ import annotations

from supabase import Client

from ..database import get_supabase_client


class MessageRepository:
    """Data access for public.messages (service role)."""

    def __init__(self, client: Client | None = None):
        self._db: Client = client or get_supabase_client()

    def get_messages(self, match_id: str, limit: int = 50, before: str | None = None) -> list[dict]:
        """Newest first."""
        query = self._db.table("messages").select("*").eq("match_id", match_id)
        if before:
            query = query.lt("sent_at", before)
        return query.order("sent_at", desc=True).limit(limit).execute().data or []

    def send_message(
        self, match_id: str, sender_id: str, receiver_id: str, content: str, msg_type: str = "text"
    ) -> dict:
        """
        Insert a message. `sent_at`/`is_read` are set and the match preview is
        updated by database triggers.
        """
        resp = (
            self._db.table("messages")
            .insert({
                "match_id": match_id,
                "sender_id": sender_id,
                "receiver_id": receiver_id,
                "content": content,
                "type": msg_type,
            })
            .execute()
        )
        return resp.data[0] if resp.data else {}

    def mark_as_read(self, match_id: str, reader_id: str) -> int:
        resp = (
            self._db.table("messages")
            .update({"is_read": True})
            .eq("match_id", match_id)
            .eq("receiver_id", reader_id)
            .eq("is_read", False)
            .execute()
        )
        return len(resp.data) if resp.data else 0
