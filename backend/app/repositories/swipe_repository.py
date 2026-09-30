from __future__ import annotations

from supabase import Client

from ..database import get_supabase_client

_PAGE = 1000  # PostgREST's default max-rows


class SwipeRepository:
    """Data access for public.swipes (service role)."""

    def __init__(self, client: Client | None = None):
        self._db: Client = client or get_supabase_client()

    def upsert_swipe(self, swiper_id: str, swiped_user_id: str, action: str) -> None:
        """
        Insert or change a swipe. The `on_swipe_match` trigger creates the match
        (atomically, once) when the like is reciprocated.
        """
        self._db.table("swipes").upsert(
            {"swiper_id": swiper_id, "swiped_user_id": swiped_user_id, "action": action},
            on_conflict="swiper_id,swiped_user_id",
        ).execute()

    def withdraw_like(self, swiper_id: str, swiped_user_id: str) -> None:
        """
        Turn the swiper's like into a dislike. Used on unmatch so the other
        person can't recreate the match by re-sending their own like (the
        database does the same for client-side unmatches).
        """
        (
            self._db.table("swipes")
            .update({"action": "dislike"})
            .eq("swiper_id", swiper_id)
            .eq("swiped_user_id", swiped_user_id)
            .in_("action", ["like", "superLike"])
            .execute()
        )

    def get_pending_liker_ids(self, user_id: str) -> set[str]:
        """Users who liked `user_id` and are still waiting on their swipe."""
        resp = self._db.rpc("get_pending_liker_ids", {"p_user_id": user_id}).execute()
        rows = resp.data or []
        # SETOF uuid comes back as bare values or as {"get_pending_liker_ids": ...}
        return {r if isinstance(r, str) else next(iter(r.values())) for r in rows}

    def get_inbound_like_counts(self, user_ids: list[str]) -> dict[str, int]:
        if not user_ids:
            return {}
        resp = self._db.rpc("get_inbound_like_counts", {"p_user_ids": user_ids}).execute()
        return {row["user_id"]: int(row["likes"]) for row in (resp.data or [])}

    def get_training_swipes(self, limit: int = 20000) -> list[dict]:
        """Most recent swipes, paginated past PostgREST's 1000-row cap."""
        rows: list[dict] = []
        start = 0
        while start < limit:
            end = min(start + _PAGE, limit) - 1
            resp = (
                self._db.table("swipes")
                .select("swiper_id, swiped_user_id, action, swiped_at")
                .order("swiped_at", desc=True)
                .range(start, end)
                .execute()
            )
            batch = resp.data or []
            rows.extend(batch)
            if len(batch) < end - start + 1:
                break
            start = end + 1
        return rows

    def get_swipe_history(self, user_id: str, limit: int = 50) -> list[dict]:
        resp = (
            self._db.table("swipes")
            .select("id, swiped_user_id, action, swiped_at")
            .eq("swiper_id", user_id)
            .order("swiped_at", desc=True)
            .limit(limit)
            .execute()
        )
        return resp.data or []
