"""
Collaboration intent
====================
GitAlong matches people *for a reason*. This module holds the vocabulary of
intents and the pure functions that turn two profiles into:

* intent compatibility   — do they want compatible things? (mentor ↔ mentee
                           is complementary; co-founder ↔ co-founder is symmetric)
* skill complementarity  — does each have what the other is looking for?
* match reasons          — short, human sentences shown on the card

Everything here is deterministic and I/O free so it can be unit-tested and
reused by the ranker, the ML features and the API.
"""
from __future__ import annotations

from collections.abc import Iterable
from datetime import UTC, datetime
from typing import Protocol

# Keep in sync with the CHECK constraint `users_looking_for_valid` and the
# Flutter/web constants (lib/core/constants/collab_constants.dart,
# GitAlong-Website/src/lib/collab.ts).
INTENT_LABELS: dict[str, str] = {
    "cofounder": "a co-founder",
    "side_project": "a side-project partner",
    "open_source": "open-source collaborators",
    "hackathon": "hackathon teammates",
    "mentor": "someone to mentor",
    "mentee": "a mentor",
}
INTENTS = frozenset(INTENT_LABELS)
_SYMMETRIC = frozenset({"cofounder", "side_project", "open_source", "hackathon"})
_COMPLEMENT = {"mentor": "mentee", "mentee": "mentor"}


class ProfileLike(Protocol):
    languages: list[str]
    interests: list[str]
    github_topics: list[str]
    looking_for: list[str]
    seeking_skills: list[str]
    location: str | None
    total_stars: int
    last_active_at: datetime | None


def _norm(values: Iterable[str] | None) -> dict[str, str]:
    """lower-cased value → first original spelling (for display)."""
    out: dict[str, str] = {}
    for v in values or []:
        if v and v.strip():
            out.setdefault(v.strip().lower(), v.strip())
    return out


def human_join(items: list[str]) -> str:
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    return ", ".join(items[:-1]) + " and " + items[-1]


def compatible_intents(a: Iterable[str], b: Iterable[str]) -> list[tuple[str, str]]:
    """Pairs (a_intent, b_intent) that make sense together."""
    a_set = {i for i in a or [] if i in INTENTS}
    b_set = {i for i in b or [] if i in INTENTS}
    pairs = [(i, i) for i in sorted(a_set & b_set & _SYMMETRIC)]
    pairs += [(i, _COMPLEMENT[i]) for i in sorted(a_set) if i in _COMPLEMENT and _COMPLEMENT[i] in b_set]
    return pairs


def intent_compatibility(a: Iterable[str], b: Iterable[str]) -> float:
    """1.0 compatible, 0.0 incompatible, 0.5 when either side hasn't said."""
    a_list = [i for i in a or [] if i in INTENTS]
    b_list = [i for i in b or [] if i in INTENTS]
    if not a_list or not b_list:
        return 0.5
    return 1.0 if compatible_intents(a_list, b_list) else 0.0


def skill_complement(viewer: ProfileLike, candidate: ProfileLike) -> float:
    """
    How well each side covers what the other is looking for (0..1).
    Averages the directions that are defined; 0 when neither side is seeking.
    """
    scores: list[float] = []
    v_seek = _norm(viewer.seeking_skills)
    c_seek = _norm(candidate.seeking_skills)
    if v_seek:
        scores.append(len(v_seek.keys() & _norm(candidate.languages).keys()) / len(v_seek))
    if c_seek:
        scores.append(len(c_seek.keys() & _norm(viewer.languages).keys()) / len(c_seek))
    return sum(scores) / len(scores) if scores else 0.0


def days_since_active(profile: ProfileLike, now: datetime | None = None) -> int | None:
    ref = profile.last_active_at
    if ref is None:
        return None
    now = now or datetime.now(UTC)
    if ref.tzinfo is None:
        ref = ref.replace(tzinfo=UTC)
    return max(0, (now - ref).days)


def _format_stars(n: int) -> str:
    return f"{n / 1000:.1f}k".replace(".0k", "k") if n >= 1000 else str(n)


def match_reasons(viewer: ProfileLike, candidate: ProfileLike, limit: int = 3) -> list[str]:
    """Short, human-readable reasons, most important first."""
    reasons: list[str] = []

    for mine, theirs in compatible_intents(viewer.looking_for, candidate.looking_for):
        if mine == theirs:
            reasons.append(f"You're both looking for {INTENT_LABELS[mine]}")
        elif mine == "mentee":
            reasons.append("Mentors developers — you're looking for a mentor")
        else:
            reasons.append("Looking for a mentor — you mentor")
        break

    cand_langs = _norm(candidate.languages)
    viewer_langs = _norm(viewer.languages)
    wanted_keys = [k for k in _norm(viewer.seeking_skills) if k in cand_langs]
    wanted = [cand_langs[k] for k in wanted_keys][:2]
    if wanted:
        reasons.append(f"Knows {human_join(wanted)} — {'a skill' if len(wanted) == 1 else 'skills'} you want")
    offered = [viewer_langs[k] for k in _norm(candidate.seeking_skills) if k in viewer_langs][:2]
    if offered:
        reasons.append(f"Looking for {human_join(offered)}, which you know")

    shared_langs = [viewer_langs[k] for k in viewer_langs if k in cand_langs and k not in wanted_keys]
    if shared_langs:
        reasons.append(f"You both write {human_join(shared_langs[:2])}")

    v_topics = _norm(list(viewer.interests) + list(viewer.github_topics))
    c_topics = _norm(list(candidate.interests) + list(candidate.github_topics))
    shared_topics = [v_topics[k] for k in v_topics if k in c_topics]
    if shared_topics:
        reasons.append(f"Both into {human_join(shared_topics[:2])}")

    if viewer.location and candidate.location:
        vl, cl = viewer.location.strip().lower(), candidate.location.strip().lower()
        if vl and cl and (vl == cl or vl in cl or cl in vl):
            reasons.append(f"Also in {candidate.location.strip()}")

    if (candidate.total_stars or 0) >= 100:
        reasons.append(f"{_format_stars(candidate.total_stars)} stars earned on GitHub")

    days = days_since_active(candidate)
    if days is not None and days <= 1:
        reasons.append("Active today")
    elif days is not None and days <= 7:
        reasons.append("Active this week")

    # De-duplicate while preserving order.
    seen: set[str] = set()
    unique = [r for r in reasons if not (r in seen or seen.add(r))]
    return unique[:limit]
