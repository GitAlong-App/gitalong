from __future__ import annotations

from supabase import Client

from ..database import get_supabase_client


def pair_key(a: str, b: str) -> str:
    """Matches the generated `matches.pair_key` column."""
    lo, hi = sorted((a, b))
    return f"{lo}:{hi}"


class MatchRepository:
    """Data access for public.matches (service role)."""

    def __init__(self, client: Client | None = None):
        self._db: Client = client or get_supabase_client()

    def get_matches_for_user(self, user_id: str, limit: int = 50, before: str | None = None) -> list[dict]:
        query = (
            self._db.table("matches")
            .select("*")
            .contains("users", [user_id])
            .order("matched_at", desc=True)
        )
        if before:
            query = query.lt("matched_at", before)
        return query.limit(limit).execute().data or []

    def get_match_by_id(self, match_id: str) -> dict | None:
        resp = self._db.table("matches").select("*").eq("id", match_id).limit(1).execute()
        rows = resp.data if resp is not None else None
        return rows[0] if rows else None

    def get_match_between(self, user_a: str, user_b: str) -> dict | None:
        resp = self._db.table("matches").select("*").eq("pair_key", pair_key(user_a, user_b)).limit(1).execute()
        rows = resp.data if resp is not None else None
        return rows[0] if rows else None

    def delete_match(self, match_id: str) -> None:
        self._db.table("matches").delete().eq("id", match_id).execute()

    def mark_read(self, match_id: str, reader_id: str) -> None:
        """
        Clear the unread flag unless the reader sent the last message. Same rule
        as the `mark_match_read` RPC (`IS DISTINCT FROM`): a plain `neq` would
        skip rows whose sender is NULL (SQL `NULL <> x` is not true).
        """
        (
            self._db.table("matches")
            .update({"is_read": True})
            .eq("id", match_id)
            .or_(f"last_message_sender_id.is.null,last_message_sender_id.neq.{reader_id}")
            .execute()
        )


def is_unread_for(row: dict, user_id: str) -> bool:
    """A match is unread for you only if the other person wrote last."""
    return (
        row.get("last_message") is not None
        and row.get("is_read") is False
        and row.get("last_message_sender_id") not in (None, user_id)
    )
