from datetime import UTC, datetime

import httpx
import pytest
from fastapi.testclient import TestClient

from app.api.v1 import matches as matches_api
from app.api.v1 import swipes as swipes_api
from app.core.auth import verify_token
from app.main import app
from app.repositories.match_repository import is_unread_for, pair_key
from app.services.github_service import GitHubService, GitHubUnavailable
from tests.conftest import make_user

ME, OTHER = "11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"


@pytest.fixture
def client():
    app.dependency_overrides[verify_token] = lambda: ME
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


def test_unread_is_per_user():
    row = {"last_message": "hi", "is_read": False, "last_message_sender_id": ME}
    assert not is_unread_for(row, ME)       # I wrote last → not unread for me
    assert is_unread_for(row, OTHER)        # …but unread for them
    assert not is_unread_for({**row, "is_read": True}, OTHER)
    assert pair_key(OTHER, ME) == f"{ME}:{OTHER}"


def test_list_matches_uses_per_user_unread_and_hides_email(client, monkeypatch):
    rows = [{
        "id": "m1", "users": [ME, OTHER], "matched_at": datetime.now(UTC).isoformat(),
        "last_message": "hey", "last_message_at": datetime.now(UTC).isoformat(),
        "last_message_sender_id": ME, "is_read": False,
    }]

    class Matches:
        def get_matches_for_user(self, *a, **k):
            return rows

    class Users:
        def bulk_get_by_ids(self, ids):
            return [make_user(OTHER, looking_for=["cofounder"], pitch="Rust DB")]

    monkeypatch.setattr(matches_api, "MatchRepository", Matches)
    monkeypatch.setattr(matches_api, "UserRepository", Users)
    body = client.get("/api/v1/matches").json()
    item = body["matches"][0]
    assert item["unread"] is False and item["is_read"] is True
    assert item["other_user"]["looking_for"] == ["cofounder"]
    assert "email" not in item["other_user"]


def test_swipe_validation(client):
    assert client.post("/api/v1/swipes", json={"swiped_user_id": OTHER, "action": "love"}).status_code == 422
    assert client.post("/api/v1/swipes", json={"swiped_user_id": ME, "action": "like"}).status_code == 400


def test_swipe_reports_match_created_by_trigger(client, monkeypatch):
    calls = []

    class Swipes:
        def upsert_swipe(self, *a):
            calls.append(a)

    class Matches:
        def get_match_between(self, a, b):
            return {"id": "m-42"}

    monkeypatch.setattr(swipes_api, "SwipeRepository", Swipes)
    monkeypatch.setattr(swipes_api, "MatchRepository", Matches)
    body = client.post("/api/v1/swipes", json={"swiped_user_id": OTHER, "action": "superLike"}).json()
    assert body == {"status": "ok", "matched": True, "match_id": "m-42"}
    assert calls == [(ME, OTHER, "superLike")]


def test_notify_match_is_a_harmless_noop(client):
    r = client.post("/api/v1/notify-match", json={"match_id": "x", "notify_user_id": OTHER, "matcher_name": "<script>"})
    assert r.status_code == 200 and r.json()["status"] == "ignored"


def test_health_hides_errors(client, monkeypatch):
    from app.api.v1 import health

    def boom():
        raise RuntimeError("password=hunter2")

    monkeypatch.setattr(health, "get_supabase_client", boom)
    body = client.get("/api/v1/health").json()
    assert body["status"] == "degraded" and "hunter2" not in str(body)


def test_unhandled_errors_are_generic_and_keep_cors(client, monkeypatch):
    class Boom:
        def get_matches_for_user(self, *a, **k):
            raise RuntimeError("secret internals")

    monkeypatch.setattr(matches_api, "MatchRepository", Boom)
    r = client.get("/api/v1/matches", headers={"Origin": "https://gitalong.app"})
    assert r.status_code == 500
    assert "secret" not in r.text
    assert r.headers.get("access-control-allow-origin") == "https://gitalong.app"


def test_cors_rejects_unknown_origins(client):
    r = client.options(
        "/api/v1/matches",
        headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "GET"},
    )
    assert r.headers.get("access-control-allow-origin") is None


def test_admin_endpoints_require_secret(client):
    assert client.get("/api/v1/admin/metrics").status_code == 401
    assert client.get("/api/v1/admin/metrics", headers={"X-Admin-Secret": "wrong"}).status_code == 401


def _gh(handler):
    return GitHubService(token="", transport=httpx.MockTransport(handler))


def test_github_stats_aggregate_owned_repos():
    def handler(request: httpx.Request):
        if request.url.path.endswith("/repos"):
            return httpx.Response(200, json=[
                {"language": "Rust", "stargazers_count": 50, "forks_count": 2, "topics": ["database", "rust"]},
                {"language": "Go", "stargazers_count": 1, "forks_count": 0, "topics": ["cli"]},
                {"language": "JavaScript", "stargazers_count": 999, "fork": True, "topics": ["forked"]},
            ])
        return httpx.Response(200, json={"login": "dev", "followers": 7, "following": 3, "public_repos": 3})

    import asyncio

    stats = asyncio.run(_gh(handler).fetch_stats("dev"))
    assert stats.total_stars == 51            # fork excluded
    assert stats.languages == ["Rust", "Go"]
    assert "forked" not in stats.topics and stats.followers == 7


def test_github_rate_limit_raises_instead_of_zeroing():
    import asyncio

    with pytest.raises(GitHubUnavailable):
        asyncio.run(_gh(lambda r: httpx.Response(403, json={"message": "rate limit"})).fetch_stats("dev"))
