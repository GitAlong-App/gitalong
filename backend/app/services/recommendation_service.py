"""
RecommendationService
=====================
Pipeline for GET /recommendations:

  1. load the viewer
  2. candidate pool from SQL (excludes self, swiped, blocked; pre-ordered by
     cheap overlap + intent) — see get_candidate_pool()
  3. optional strict filters
  4. collaborative popularity for the pool (one SQL aggregate)
  5. hybrid scoring (HeavyRecommendationEngine) + optional ML re-rank
  6. soft-preference blend
  7. interleave people who already liked the viewer so mutual matches happen
     without revealing who liked you
  8. attach human-readable match reasons; never return email
"""
from __future__ import annotations

from datetime import UTC, datetime

from ..config import get_settings
from ..models.recommendation import RecommendationResponse, ScoredCandidate
from ..models.user import UserProfile
from ..repositories.swipe_repository import SwipeRepository
from ..repositories.user_repository import UserRepository
from . import collab
from .heavy_recommendation_engine import HeavyRecommendationEngine
from .ml_ranker import MlRanker


class ProfileNotFoundError(ValueError):
    """The viewer has no profile row yet."""


def interleave_priority(ids: list[str], priority: set[str], every: int = 3) -> list[str]:
    """
    Place priority ids at positions 0, every, 2*every, … while keeping the
    relative order of both groups.
    """
    prio = [i for i in ids if i in priority]
    rest = [i for i in ids if i not in priority]
    out: list[str] = []
    while prio or rest:
        if prio and len(out) % every == 0:
            out.append(prio.pop(0))
        elif rest:
            out.append(rest.pop(0))
        else:
            out.append(prio.pop(0))
    return out


class RecommendationService:
    def __init__(
        self,
        user_repo: UserRepository | None = None,
        swipe_repo: SwipeRepository | None = None,
        ml_ranker_factory=None,
    ):
        self._users = user_repo or UserRepository()
        self._swipes = swipe_repo or SwipeRepository()
        self._engine = HeavyRecommendationEngine()
        self._settings = get_settings()
        self._ml_ranker_factory = ml_ranker_factory or (lambda: MlRanker(model_name=self._settings.ml_model_name))

    async def get_recommendations(
        self, user_id: str, limit: int | None = None, filters: dict | None = None
    ) -> RecommendationResponse:
        limit = limit or self._settings.recommendation_limit
        filters = filters or {}
        filter_mode = (filters.get("filter_mode") or "soft").lower()
        has_filters = self.has_active_filters(filters)

        viewer = self._users.get_by_id(user_id)
        if viewer is None:
            raise ProfileNotFoundError("Profile not found. Open the app once to create it.")

        pool_size = self._settings.candidate_pool_size * (2 if has_filters else 1)
        candidates = self._users.get_candidate_pool(user_id, limit=max(pool_size, limit))
        if filter_mode == "strict" and has_filters:
            candidates = [c for c in candidates if self.matches_filters(c, filters)]
        if not candidates:
            return RecommendationResponse(user_id=user_id, recommendations=[], total=0, algorithm="collab_hybrid_v3")

        by_id = {c.id: c for c in candidates}
        cf_signal = self._swipes.get_inbound_like_counts(list(by_id))
        max_cf = max(cf_signal.values(), default=1)

        scored: list[ScoredCandidate] = self._engine.score_candidates(
            current_user=viewer, candidates=candidates, cf_liked_by=cf_signal, max_cf_count=max_cf
        )
        base = {s.user_id: s.score / 100.0 for s in scored}

        ml_scores: dict[str, float] = {}
        if self._settings.ml_ranking_enabled:
            ranker = self._ml_ranker_factory()
            if ranker.available:
                for cand in candidates:
                    res = ranker.score_pair(
                        viewer=viewer, candidate=cand, cf_count=cf_signal.get(cand.id, 0), max_cf=max_cf
                    )
                    if res is not None:
                        ml_scores[cand.id] = res.score

        pref_scores: dict[str, float] = {}
        if has_filters and filter_mode == "soft":
            pref_scores = {c.id: self.preference_score(c, filters) for c in candidates}

        def rank_key(s: ScoredCandidate) -> tuple[float, float]:
            primary = ml_scores.get(s.user_id, base[s.user_id]) if ml_scores else base[s.user_id]
            if pref_scores:
                primary = primary * 0.8 + pref_scores.get(s.user_id, 0.0) * 0.2
            return (primary, s.score)

        scored.sort(key=rank_key, reverse=True)
        ordered = [s.user_id for s in scored]

        pending_likers = self._swipes.get_pending_liker_ids(user_id) & set(by_id)
        if pending_likers:
            ordered = interleave_priority(ordered, pending_likers, every=3)

        score_by_id = {s.user_id: s for s in scored}
        recommendations: list[dict] = []
        for uid in ordered[:limit]:
            cand = by_id[uid]
            s = score_by_id[uid]
            item = cand.to_public().model_dump(mode="json")
            item["match_score"] = s.score
            item["score_breakdown"] = s.score_breakdown
            item["match_reasons"] = collab.match_reasons(viewer, cand)
            if ml_scores:
                item["ml_like_prob"] = round(ml_scores.get(uid, 0.0), 6)
            if pref_scores:
                item["filter_preference_score"] = round(pref_scores.get(uid, 0.0), 6)
            recommendations.append(item)

        return RecommendationResponse(
            user_id=user_id,
            recommendations=recommendations,
            total=len(recommendations),
            algorithm="ml_logreg_rerank_v2" if ml_scores else "collab_hybrid_v3",
        )

    # ── filters ──────────────────────────────────────────────────────────────

    @staticmethod
    def _positive(value) -> float | None:
        """A minimum of 0 (or less) constrains nothing, so it is not a filter."""
        return float(value) if value is not None and float(value) > 0 else None

    @classmethod
    def has_active_filters(cls, filters: dict) -> bool:
        return bool(
            filters.get("languages")
            or filters.get("interests")
            or filters.get("looking_for")
            or filters.get("location")
            or cls._positive(filters.get("min_followers")) is not None
            or cls._positive(filters.get("min_public_repos")) is not None
            or filters.get("active_within_days") is not None
        )

    @classmethod
    def _checks(cls, candidate: UserProfile, filters: dict) -> list[float]:
        """One score in [0, 1] per active filter."""
        def lower(values) -> set[str]:
            return {v.strip().lower() for v in values or [] if v and v.strip()}

        checks: list[float] = []
        if lower(filters.get("languages")):
            checks.append(1.0 if lower(candidate.languages) & lower(filters["languages"]) else 0.0)
        if lower(filters.get("interests")):
            topics = lower(list(candidate.interests) + list(candidate.github_topics))
            checks.append(1.0 if topics & lower(filters["interests"]) else 0.0)
        if lower(filters.get("looking_for")):
            wanted = [i for i in lower(filters["looking_for"]) if i in collab.INTENTS]
            checks.append(1.0 if collab.compatible_intents(wanted, candidate.looking_for) else 0.0)
        location = (filters.get("location") or "").strip().lower()
        if location:
            checks.append(1.0 if location in (candidate.location or "").lower() else 0.0)
        # A minimum of 0 used to become a check of followers/1, which scored
        # everyone with 0 followers as a miss (and dropped them in strict mode).
        if (min_followers := cls._positive(filters.get("min_followers"))) is not None:
            checks.append(min(1.0, max(0, candidate.followers) / min_followers))
        if (min_repos := cls._positive(filters.get("min_public_repos"))) is not None:
            checks.append(min(1.0, max(0, candidate.public_repos) / min_repos))
        if filters.get("active_within_days") is not None:
            ref = candidate.last_active_at or candidate.created_at
            if ref.tzinfo is None:
                ref = ref.replace(tzinfo=UTC)
            days = max(0, (datetime.now(UTC) - ref).days)
            checks.append(1.0 if days <= int(filters["active_within_days"]) else 0.0)
        return checks

    @classmethod
    def matches_filters(cls, candidate: UserProfile, filters: dict) -> bool:
        return all(c >= 1.0 for c in cls._checks(candidate, filters))

    @classmethod
    def preference_score(cls, candidate: UserProfile, filters: dict) -> float:
        checks = cls._checks(candidate, filters)
        return sum(checks) / len(checks) if checks else 0.0
