"""
Hybrid recommendation engine
============================
Scores a candidate pool for one viewer. Deterministic and I/O free.

Signals (weights sum to 1.0):

  intent        0.20  Do they want compatible things? (collab.intent_compatibility)
  complement    0.20  Does each have skills the other is looking for?
  tech          0.20  Jaccard overlap of languages
  interests     0.15  TF-IDF cosine over interests + GitHub repo topics
  activity      0.10  Similar developer "tier" (log-scaled followers/repos/stars)
  community     0.05  Distinct inbound likes, normalised within the pool
  recency       0.05  Recently active
  location      0.05  Same / overlapping location

A small quality multiplier rewards complete profiles (bio, avatar, pitch).
The original engine rewarded only similarity; collaboration usually needs
*compatible goals* and *complementary skills*, so those now carry 40%.
"""
from __future__ import annotations

import math
from datetime import UTC, datetime

try:  # scikit-learn is optional at import time; fall back to Jaccard.
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity
except ImportError:  # pragma: no cover
    TfidfVectorizer = None
    cosine_similarity = None

from ..models.recommendation import ScoredCandidate
from ..models.user import UserProfile
from . import collab


def _lower_set(values) -> set[str]:
    return {v.strip().lower() for v in values or [] if v and v.strip()}


def jaccard(a, b) -> float:
    sa, sb = _lower_set(a), _lower_set(b)
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / len(sa | sb)


def _topics(p: UserProfile) -> list[str]:
    return list(p.interests or []) + list(p.github_topics or [])


class HeavyRecommendationEngine:
    W_INTENT = 0.20
    W_COMPLEMENT = 0.20
    W_TECH = 0.20
    W_INTERESTS = 0.15
    W_ACTIVITY = 0.10
    W_COMMUNITY = 0.05
    W_RECENCY = 0.05
    W_LOCATION = 0.05

    def score_candidates(
        self,
        current_user: UserProfile,
        candidates: list[UserProfile],
        cf_liked_by: dict[str, int],
        max_cf_count: int = 1,
    ) -> list[ScoredCandidate]:
        if not candidates:
            return []

        interest_scores = self._interest_similarity(current_user, candidates)
        max_cf = max(max_cf_count, 1)
        scored: list[ScoredCandidate] = []

        for i, cand in enumerate(candidates):
            parts = {
                "intent_fit": collab.intent_compatibility(current_user.looking_for, cand.looking_for),
                "skill_complement": collab.skill_complement(current_user, cand),
                "tech_match": jaccard(current_user.languages, cand.languages),
                "interest_match": interest_scores[i],
                "activity_level": self._activity_similarity(current_user, cand),
                "community_popularity": min(1.0, cf_liked_by.get(cand.id, 0) / max_cf),
                "recency_boost": self._recency(cand.last_active_at),
                "location_bonus": self._location(current_user.location, cand.location),
            }
            raw = (
                parts["intent_fit"] * self.W_INTENT
                + parts["skill_complement"] * self.W_COMPLEMENT
                + parts["tech_match"] * self.W_TECH
                + parts["interest_match"] * self.W_INTERESTS
                + parts["activity_level"] * self.W_ACTIVITY
                + parts["community_popularity"] * self.W_COMMUNITY
                + parts["recency_boost"] * self.W_RECENCY
                + parts["location_bonus"] * self.W_LOCATION
            )

            multiplier = 1.0
            if cand.bio and cand.bio.strip():
                multiplier += 0.04
            if cand.avatar_url:
                multiplier += 0.03
            if cand.pitch and cand.pitch.strip():
                multiplier += 0.05

            scored.append(
                ScoredCandidate(
                    user_id=cand.id,
                    username=cand.username,
                    score=round(min(100.0, raw * 100.0 * multiplier), 1),
                    score_breakdown={k: round(v * 100, 1) for k, v in parts.items()},
                )
            )

        scored.sort(key=lambda s: s.score, reverse=True)
        return scored

    # ── signals ──────────────────────────────────────────────────────────────

    @staticmethod
    def _interest_similarity(user: UserProfile, candidates: list[UserProfile]) -> list[float]:
        user_topics = _topics(user)
        if TfidfVectorizer is None or not user_topics:
            return [jaccard(user_topics, _topics(c)) for c in candidates]
        # Treat each topic as one token ("AI / ML" → "ai_ml") so multi-word
        # labels don't spuriously match on shared words like "dev".
        def doc(topics: list[str]) -> str:
            return " ".join("_".join(t.lower().replace("/", " ").split()) for t in topics if t and t.strip())

        docs = [doc(user_topics)] + [doc(_topics(c)) for c in candidates]
        try:
            matrix = TfidfVectorizer(token_pattern=r"[^\s]+").fit_transform(docs)
            return cosine_similarity(matrix[0:1], matrix[1:])[0].tolist()
        except ValueError:  # empty vocabulary
            return [0.0] * len(candidates)

    @staticmethod
    def _activity_similarity(user: UserProfile, cand: UserProfile) -> float:
        """1 - relative gap in log-scaled activity. Keeps juniors with peers."""
        def tier(p: UserProfile) -> float:
            # Clamp: legacy rows could hold negative counters (clients used to
            # write them), and log1p(x <= -1) raises, failing the whole request.
            return math.log1p(max(0, p.followers) * 2 + max(0, p.public_repos) * 5 + max(0, p.total_stars))

        u, c = tier(user), tier(cand)
        if u == 0 and c == 0:
            return 0.5
        return max(0.0, 1.0 - abs(u - c) / max(u, c))

    @staticmethod
    def _recency(last_active: datetime | None) -> float:
        if not last_active:
            return 0.0
        if last_active.tzinfo is None:
            last_active = last_active.replace(tzinfo=UTC)
        days = (datetime.now(UTC) - last_active).days
        if days <= 1:
            return 1.0
        if days <= 3:
            return 0.8
        if days <= 7:
            return 0.5
        if days <= 30:
            return 0.2
        return 0.0

    @staticmethod
    def _location(a: str | None, b: str | None) -> float:
        if not a or not b:
            return 0.0
        a, b = a.strip().lower(), b.strip().lower()
        if not a or not b:
            return 0.0
        if a == b:
            return 1.0
        if a in b or b in a:
            return 0.5
        return 0.0
