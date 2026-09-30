from __future__ import annotations

import math
from datetime import UTC, datetime

from ..models.user import UserProfile
from . import collab


def _safe_lower_set(values: list[str] | None) -> set[str]:
    return {v.strip().lower() for v in values or [] if v and v.strip()}


def _jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def _recency_days(profile: UserProfile) -> int:
    ref = profile.last_active_at or profile.created_at
    if ref.tzinfo is None:
        ref = ref.replace(tzinfo=UTC)
    return max(0, (datetime.now(UTC) - ref).days)


def extract_pair_features(
    viewer: UserProfile,
    candidate: UserProfile,
    *,
    cf_count: int = 0,
    max_cf: int = 1,
) -> dict[str, float]:
    """
    Deterministic, cheap feature set shared by training and inference.
    Adding a feature is backwards compatible (unknown weights default to 0);
    renaming or re-scaling one requires a retrain.
    """
    viewer_lang = _safe_lower_set(viewer.languages)
    cand_lang = _safe_lower_set(candidate.languages)
    viewer_topics = _safe_lower_set(list(viewer.interests) + list(viewer.github_topics))
    cand_topics = _safe_lower_set(list(candidate.interests) + list(candidate.github_topics))

    v_follow = math.log1p(max(0, viewer.followers))
    c_follow = math.log1p(max(0, candidate.followers))
    v_repos = math.log1p(max(0, viewer.public_repos))
    c_repos = math.log1p(max(0, candidate.public_repos))
    follow_sim = 1.0 - (abs(v_follow - c_follow) / max(v_follow, c_follow, 1e-6))
    repos_sim = 1.0 - (abs(v_repos - c_repos) / max(v_repos, c_repos, 1e-6))

    days = _recency_days(candidate)

    return {
        # overlaps
        "lang_jaccard": _jaccard(viewer_lang, cand_lang),
        "topic_jaccard": _jaccard(viewer_topics, cand_topics),
        "lang_intersection": float(len(viewer_lang & cand_lang)),
        "topic_intersection": float(len(viewer_topics & cand_topics)),
        # collaboration intent
        "intent_compat": collab.intent_compatibility(viewer.looking_for, candidate.looking_for),
        "skill_complement": collab.skill_complement(viewer, candidate),
        # activity similarity
        "followers_sim": max(0.0, min(1.0, follow_sim)),
        "repos_sim": max(0.0, min(1.0, repos_sim)),
        # quality proxies
        "cand_has_avatar": 1.0 if candidate.avatar_url else 0.0,
        "cand_has_bio": 1.0 if (candidate.bio and candidate.bio.strip()) else 0.0,
        "cand_has_pitch": 1.0 if (candidate.pitch and candidate.pitch.strip()) else 0.0,
        # recency
        "cand_rec_le_7d": 1.0 if days <= 7 else 0.0,
        "cand_rec_le_30d": 1.0 if days <= 30 else 0.0,
        "cand_rec_le_90d": 1.0 if days <= 90 else 0.0,
        # popularity
        "cf_norm": max(0.0, min(1.0, float(cf_count) / float(max(max_cf, 1)))),
        "bias": 1.0,
    }
