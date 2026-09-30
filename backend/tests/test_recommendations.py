import asyncio

from app.services.heavy_recommendation_engine import HeavyRecommendationEngine
from app.services.recommendation_service import RecommendationService, interleave_priority
from tests.conftest import make_user


class FakeUsers:
    def __init__(self, viewer, pool):
        self.viewer, self.pool = viewer, pool

    def get_by_id(self, uid):
        return self.viewer if uid == self.viewer.id else next((p for p in self.pool if p.id == uid), None)

    def get_candidate_pool(self, uid, limit=200):
        return list(self.pool)[:limit]


class FakeSwipes:
    def __init__(self, likes=None, pending=None):
        self.likes, self.pending = likes or {}, pending or set()

    def get_inbound_like_counts(self, ids):
        return {i: self.likes[i] for i in ids if i in self.likes}

    def get_pending_liker_ids(self, uid):
        return set(self.pending)


def _service(viewer, pool, **swipes):
    return RecommendationService(user_repo=FakeUsers(viewer, pool), swipe_repo=FakeSwipes(**swipes))


def test_engine_prefers_compatible_intent_and_complementary_skills():
    viewer = make_user("v", languages=["Rust"], looking_for=["cofounder"], seeking_skills=["TypeScript"])
    fit = make_user("fit", languages=["TypeScript"], looking_for=["cofounder"])
    clone = make_user("clone", languages=["Rust"], looking_for=["hackathon"])
    scored = HeavyRecommendationEngine().score_candidates(viewer, [clone, fit], cf_liked_by={}, max_cf_count=1)
    assert [s.user_id for s in scored] == ["fit", "clone"]
    assert all(0 <= s.score <= 100 for s in scored)
    assert set(scored[0].score_breakdown) == {
        "intent_fit", "skill_complement", "tech_match", "interest_match",
        "activity_level", "community_popularity", "recency_boost", "location_bonus",
    }


def test_multiword_topics_do_not_match_on_shared_words():
    viewer = make_user("v", interests=["Web Dev"])
    web = make_user("web", interests=["Web Dev"])
    mobile = make_user("mob", interests=["Mobile Dev"])
    scores = HeavyRecommendationEngine()._interest_similarity(viewer, [web, mobile])
    assert scores[0] > 0.99 and scores[1] == 0.0


def test_response_has_reasons_and_never_email():
    viewer = make_user("v", languages=["Rust"], looking_for=["open_source"])
    pool = [make_user(f"c{i}", languages=["Rust"], looking_for=["open_source"]) for i in range(5)]
    resp = asyncio.run(_service(viewer, pool).get_recommendations("v", limit=3))
    assert resp.total == 3
    for item in resp.recommendations:
        assert "email" not in item
        assert item["match_reasons"], item
        assert 0 <= item["match_score"] <= 100
    assert resp.algorithm == "collab_hybrid_v3"


def test_strict_looking_for_filter():
    viewer = make_user("v", looking_for=["mentee"])
    pool = [make_user("mentor", looking_for=["mentor"]), make_user("founder", looking_for=["cofounder"])]
    resp = asyncio.run(
        _service(viewer, pool).get_recommendations("v", filters={"looking_for": ["mentee"], "filter_mode": "strict"})
    )
    assert [r["id"] for r in resp.recommendations] == ["mentor"]


def test_pending_likers_are_interleaved_not_stacked():
    assert interleave_priority(list("abcdefg"), {"e", "f", "g"}, every=3) == list("eabfcdg")
    viewer = make_user("v", languages=["Rust"])
    strong = [make_user(f"s{i}", languages=["Rust"], bio="hi", pitch="x") for i in range(4)]
    weak = [make_user(f"w{i}") for i in range(2)]
    resp = asyncio.run(_service(viewer, strong + weak, pending={"w0", "w1"}).get_recommendations("v", limit=6))
    ids = [r["id"] for r in resp.recommendations]
    assert ids[0] in {"w0", "w1"} and ids[3] in {"w0", "w1"}


def test_unknown_viewer_raises():
    import pytest

    with pytest.raises(ValueError):
        asyncio.run(_service(make_user("v"), []).get_recommendations("someone-else"))


def test_minimum_counts_of_zero_constrain_nothing():
    viewer = make_user("v", languages=["Rust"])
    pool = [make_user("newbie", languages=["Rust"], followers=0, public_repos=0),
            make_user("veteran", languages=["Rust"], followers=50, public_repos=20)]
    zero = {"min_followers": 0, "min_public_repos": 0, "filter_mode": "strict"}
    resp = asyncio.run(_service(viewer, pool).get_recommendations("v", filters=zero))
    assert {r["id"] for r in resp.recommendations} == {"newbie", "veteran"}
    assert not RecommendationService.has_active_filters(zero)
    # a real minimum still filters
    resp = asyncio.run(
        _service(viewer, pool).get_recommendations("v", filters={"min_followers": 10, "filter_mode": "strict"})
    )
    assert [r["id"] for r in resp.recommendations] == ["veteran"]


def test_null_array_elements_do_not_break_profiles():
    # Array columns are client-writable; Postgres accepts ['Rust', NULL].
    user = make_user("bad", languages=["Rust", None], interests=[None], seeking_skills=[None, "Go", ["nested"]])
    assert user.languages == ["Rust"] and user.interests == [] and user.seeking_skills == ["Go"]
    assert user.to_public().languages == ["Rust"]


def test_one_bad_row_does_not_break_everyone_elses_recommendations():
    viewer = make_user("v", languages=["Rust"])
    pool = [make_user("ok", languages=["Rust"]),
            make_user("bad", languages=["Rust", None], followers=-5, public_repos=-1, total_stars=-10)]
    resp = asyncio.run(_service(viewer, pool).get_recommendations("v", limit=5))
    assert {r["id"] for r in resp.recommendations} == {"ok", "bad"}
    assert all(0 <= r["match_score"] <= 100 for r in resp.recommendations)
