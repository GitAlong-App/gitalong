from __future__ import annotations

from datetime import UTC, datetime

from supabase import Client

from ..database import get_supabase_client
from ..models.user import UserProfile


class UserRepository:
    """
    Data access for public.users (service role — bypasses RLS, so every
    method must scope its query deliberately).
    """

    def __init__(self, client: Client | None = None):
        self._db: Client = client or get_supabase_client()

    def get_by_id(self, user_id: str) -> UserProfile | None:
        resp = self._db.table("users").select("*").eq("id", user_id).limit(1).execute()
        rows = resp.data if resp is not None else None
        return UserProfile(**rows[0]) if rows else None

    def bulk_get_by_ids(self, user_ids: list[str]) -> list[UserProfile]:
        ids = list(dict.fromkeys(i for i in user_ids if i))
        if not ids:
            return []
        out: list[UserProfile] = []
        for start in range(0, len(ids), 200):  # keep URLs short
            resp = self._db.table("users").select("*").in_("id", ids[start:start + 200]).execute()
            out.extend(UserProfile(**row) for row in (resp.data or []))
        return out

    def get_candidate_pool(self, user_id: str, limit: int = 200) -> list[UserProfile]:
        """
        Candidate generation in SQL (see get_candidate_pool in the security
        migration): excludes self, already-swiped and blocked users server-side
        and pre-orders by cheap overlap + intent.
        """
        resp = self._db.rpc("get_candidate_pool", {"p_user_id": user_id, "p_limit": limit}).execute()
        return [UserProfile(**row) for row in (resp.data or [])]

    def update_github_stats(
        self,
        user_id: str,
        *,
        followers: int,
        following: int,
        public_repos: int,
        total_stars: int,
        topics: list[str],
        detected_languages: list[str],
        profile: dict,
    ) -> UserProfile | None:
        """
        Store GitHub-derived facts. User-curated fields (languages, bio,
        location, company) are only filled when the user hasn't set them.
        """
        current = self.get_by_id(user_id)
        if current is None:
            return None

        updates: dict = {
            "followers": followers,
            "following": following,
            "public_repos": public_repos,
            "total_stars": total_stars,
            "github_topics": topics[:30],
            "github_synced_at": datetime.now(UTC).isoformat(),
        }
        if not current.languages and detected_languages:
            updates["languages"] = detected_languages[:10]
        for field in ("bio", "location", "company", "avatar_url", "name"):
            value = profile.get(field)
            if value and not getattr(current, field):
                updates[field] = value
        if profile.get("blog") and not current.website_url:
            blog = str(profile["blog"]).strip()
            updates["website_url"] = blog if blog.startswith("http") else f"https://{blog}"
        if profile.get("html_url"):
            updates["github_url"] = profile["html_url"]

        resp = self._db.table("users").update(updates).eq("id", user_id).execute()
        rows = resp.data if resp is not None else None
        return UserProfile(**rows[0]) if rows else self.get_by_id(user_id)
