import asyncio
import json
from types import SimpleNamespace

import httpx
import pytest
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError

from app.api.v1 import matches as matches_api
from app.api.v1 import messages as messages_api
from app.api.v1 import recommendations as rec_api
from app.api.v1 import swipes as swipes_api
from app.api.v1 import users as users_api
from app.core.auth import verify_token
from app.main import app
from app.repositories.match_repository import MatchRepository
from app.repositories.swipe_repository import SwipeRepository
from app.services.github_service import GitHubService, GitHubStats, GitHubUnavailable
from app.services.recommendation_service import ProfileNotFoundError
from tests.conftest import make_user, pgrst

ME, OTHER = "11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"
MID = "33333333-3333-3333-3333-333333333333"
MIXED = "abcdefab-cdef-4bcd-8fab-cdefabcdefab"  # has hex letters, unlike ME/OTHER


@pytest.fixture
def client():
    app.dependency_overrides[verify_token] = lambda: ME
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


def _never(name):
    def fail(*_a, **_k):
        raise AssertionError(f"{name} must not be used here")
    return fail


class _Match:
    """MatchRepository stand-in holding one match between ME and OTHER."""

    def __init__(self, calls=None, users=(ME, OTHER)):
        self.calls = [] if calls is None else calls
        self.users = list(users)

    def get_match_by_id(self, match_id):
        return {"id": MID, "users": self.users} if match_id == MID else None

    def delete_match(self, match_id):
        self.calls.append(("delete", match_id))


# ── Unmatch must stick ───────────────────────────────────────────────────────

def test_unmatch_withdraws_the_callers_like_before_deleting(client, monkeypatch):
    calls = []

    class Swipes:
        def withdraw_like(self, swiper, swiped):
            calls.append(("withdraw", swiper, swiped))

    monkeypatch.setattr(matches_api, "MatchRepository", lambda: _Match(calls))
    monkeypatch.setattr(matches_api, "SwipeRepository", Swipes)
    r = client.delete(f"/api/v1/matches/{MID}")
    assert r.status_code == 204 and r.content == b""
    assert calls == [("withdraw", ME, OTHER), ("delete", MID)]


def test_non_member_cannot_unmatch(client, monkeypatch):
    calls = []
    monkeypatch.setattr(matches_api, "MatchRepository", lambda: _Match(calls, users=(OTHER, MIXED)))
    monkeypatch.setattr(matches_api, "SwipeRepository", _never("SwipeRepository"))
    assert client.delete(f"/api/v1/matches/{MID}").status_code == 404
    assert calls == []


def test_withdraw_like_only_turns_likes_into_a_dislike():
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json=[])

    SwipeRepository(client=pgrst(handler)).withdraw_like(ME, OTHER)
    (req,) = seen
    assert req.method == "PATCH" and req.url.path == "/swipes"
    assert json.loads(req.content) == {"action": "dislike"}
    assert req.url.params["swiper_id"] == f"eq.{ME}"
    assert req.url.params["swiped_user_id"] == f"eq.{OTHER}"
    assert req.url.params["action"] == "in.(like,superLike)"


# ── Read state: same NULL semantics as the mark_match_read RPC ──────────────

def test_mark_read_also_clears_matches_whose_last_sender_is_null():
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json=[])

    MatchRepository(client=pgrst(handler)).mark_read(MID, ME)
    (req,) = seen
    assert req.method == "PATCH" and json.loads(req.content) == {"is_read": True}
    assert req.url.params["id"] == f"eq.{MID}"
    # `last_message_sender_id=neq.ME` alone never matches NULL (SQL NULL <> x is not true)
    assert req.url.params["or"] == f"(last_message_sender_id.is.null,last_message_sender_id.neq.{ME})"
    assert "last_message_sender_id" not in req.url.params


@pytest.mark.parametrize(
    "total,limit", [(0, 20000), (999, 20000), (1000, 20000), (2500, 20000), (1500, 1500), (3000, 2000)]
)
def test_training_swipes_paginate_without_gaps_or_overlap(total, limit):
    table = [{"swiper_id": f"s{i}", "swiped_user_id": "x", "action": "like", "swiped_at": str(i)} for i in range(total)]

    def handler(request):
        offset, count = int(request.url.params["offset"]), int(request.url.params["limit"])
        count = min(count, 1000)  # PostgREST max-rows
        return httpx.Response(200, json=table[offset:offset + count])

    assert SwipeRepository(client=pgrst(handler)).get_training_swipes(limit=limit) == table[:min(total, limit)]


@pytest.mark.parametrize(
    "body",
    [[OTHER, MIXED], [{"get_pending_liker_ids": OTHER}, {"get_pending_liker_ids": MIXED}], []],
)
def test_pending_liker_ids_parse_both_setof_uuid_shapes(body):
    def handler(request):
        assert request.url.path == "/rpc/get_pending_liker_ids"
        assert json.loads(request.content) == {"p_user_id": ME}
        return httpx.Response(200, json=body)

    expected = {OTHER, MIXED} if body else set()
    assert SwipeRepository(client=pgrst(handler)).get_pending_liker_ids(ME) == expected


# ── GET /users/{id}: block check in both directions, never an email ─────────

@pytest.mark.parametrize("blocked", [True, False])
def test_public_profile_checks_blocks_both_ways_and_hides_email(client, monkeypatch, blocked):
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json=[{"blocker_id": OTHER}] if blocked else [])

    class Users:
        def get_by_id(self, uid):
            return make_user(uid)

    monkeypatch.setattr(users_api, "get_supabase_client", lambda: pgrst(handler))
    monkeypatch.setattr(users_api, "UserRepository", Users)
    r = client.get(f"/api/v1/users/{OTHER}")
    (req,) = seen
    assert req.url.path == "/blocks"
    assert req.url.params["or"] == (
        f"(and(blocker_id.eq.{ME},blocked_id.eq.{OTHER}),and(blocker_id.eq.{OTHER},blocked_id.eq.{ME}))"
    )
    if blocked:
        assert r.status_code == 404
    else:
        assert r.status_code == 200 and r.json()["id"] == OTHER and "email" not in r.json()


# ── Input validation: client errors are 4xx, never a database 500 ───────────

def test_malformed_ids_are_not_found_and_never_reach_the_database(client, monkeypatch):
    monkeypatch.setattr(matches_api, "MatchRepository", _never("MatchRepository"))
    monkeypatch.setattr(users_api, "get_supabase_client", _never("get_supabase_client"))
    for method, path in [
        ("get", "/api/v1/matches/not-a-uuid"),
        ("delete", "/api/v1/matches/not-a-uuid"),
        ("get", "/api/v1/matches/not-a-uuid/messages"),
        ("put", "/api/v1/matches/not-a-uuid/messages/read"),
        # would otherwise be spliced into the PostgREST `or=(...)` filter
        ("get", "/api/v1/users/x),or(blocker_id.not.is.null"),
    ]:
        r = getattr(client, method)(path)
        assert r.status_code == 404, (method, path, r.status_code)


def test_malformed_cursor_is_422(client, monkeypatch):
    monkeypatch.setattr(matches_api, "MatchRepository", _never("MatchRepository"))
    assert client.get("/api/v1/matches?before=yesterday").status_code == 422


def test_swipe_target_is_a_canonical_uuid(client, monkeypatch):
    calls, lookups = [], []

    class Swipes:
        def upsert_swipe(self, *a):
            calls.append(a)

    class Matches:
        def get_match_between(self, a, b):
            lookups.append((a, b))
            return None

    monkeypatch.setattr(swipes_api, "SwipeRepository", Swipes)
    monkeypatch.setattr(swipes_api, "MatchRepository", Matches)
    assert client.post("/api/v1/swipes", json={"swiped_user_id": "nope", "action": "like"}).status_code == 422
    assert client.post("/api/v1/swipes", json={"swiped_user_id": MIXED.upper(), "action": "like"}).status_code == 201
    assert calls == [(ME, MIXED, "like")] and lookups == [(ME, MIXED)]  # lower-cased, like Postgres' pair_key

    app.dependency_overrides[verify_token] = lambda: MIXED
    assert client.post("/api/v1/swipes", json={"swiped_user_id": MIXED.upper(), "action": "like"}).status_code == 400


def test_swipe_on_a_missing_user_is_404(client, monkeypatch):
    class Swipes:
        def upsert_swipe(self, *a):
            raise APIError({"code": "23503", "message": 'insert or update on table "swipes" violates foreign key'})

    monkeypatch.setattr(swipes_api, "SwipeRepository", Swipes)
    r = client.post("/api/v1/swipes", json={"swiped_user_id": OTHER, "action": "like"})
    assert r.status_code == 404 and "foreign key" not in r.text


# ── Messages are stored verbatim ─────────────────────────────────────────────

def test_message_content_is_sent_verbatim(client, monkeypatch):
    sent = []

    class Messages:
        def send_message(self, match_id, sender, receiver, content, msg_type):
            sent.append(content)
            return {"id": "msg-1", "match_id": match_id, "sender_id": sender, "receiver_id": receiver,
                    "content": content, "type": msg_type, "sent_at": "2026-01-01T00:00:00+00:00", "is_read": False}

    monkeypatch.setattr(matches_api, "MatchRepository", lambda: _Match())
    monkeypatch.setattr(messages_api, "MessageRepository", Messages)
    monkeypatch.setattr(messages_api, "_is_blocked", lambda a, b: False)
    code = '    fn main() {\n        println!("<{}>", Vec::<String>::new().len());\n    }\n'
    r = client.post(f"/api/v1/matches/{MID}/messages", json={"receiver_id": OTHER, "content": code, "type": "code"})
    assert r.status_code == 201, r.text
    assert sent == [code] and r.json()["message"]["content"] == code
    r = client.post(f"/api/v1/matches/{MID}/messages", json={"receiver_id": OTHER, "content": " \n\t "})
    assert r.status_code == 422 and len(sent) == 1


# ── GitHub sync only for a verified GitHub identity ──────────────────────────

def _admin_client(identities):
    user = SimpleNamespace(identities=identities)
    admin = SimpleNamespace(get_user_by_id=lambda uid: SimpleNamespace(user=user))
    return SimpleNamespace(auth=SimpleNamespace(admin=admin))


def _identity(provider, **data):
    return SimpleNamespace(provider=provider, identity_data=data)


def test_linked_github_login_comes_only_from_a_github_identity(monkeypatch):
    def use(*identities):
        monkeypatch.setattr(users_api, "get_supabase_client", lambda: _admin_client(list(identities)))

    use(_identity("google", user_name="torvalds", email="torvalds@gmail.com"))
    assert users_api.linked_github_login(ME) is None
    use(_identity("google"), _identity("github", user_name="octo-cat", preferred_username="ignored"))
    assert users_api.linked_github_login(ME) == "octo-cat"
    use(_identity("github", preferred_username="octocat"))
    assert users_api.linked_github_login(ME) == "octocat"
    use(_identity("github", user_name="../orgs/evil?x=1"))  # never spliced into the GitHub API path
    assert users_api.linked_github_login(ME) is None


class _Users:
    def __init__(self, written):
        self.written = written

    def get_by_id(self, uid):
        # A Google sign-up: username came from the e-mail address, no github_url.
        return make_user(ME, username="torvalds", github_url=None)

    def update_github_stats(self, uid, **kwargs):
        self.written.append(kwargs)
        return make_user(ME)


def test_refresh_github_never_falls_back_to_the_username(client, monkeypatch):
    fetched, written = [], []

    class GitHub:
        async def fetch_stats(self, login):
            fetched.append(login)
            return GitHubStats(profile={}, followers=9, following=0, public_repos=1, total_stars=5, total_forks=0)

    monkeypatch.setattr(users_api, "UserRepository", lambda: _Users(written))
    monkeypatch.setattr(users_api, "GitHubService", GitHub)

    monkeypatch.setattr(users_api, "linked_github_login", lambda uid: None)
    r = client.post("/api/v1/users/me/refresh-github")
    assert r.status_code == 409 and fetched == [] and written == []

    def lookup_down(uid):
        raise RuntimeError("auth admin API unreachable")

    monkeypatch.setattr(users_api, "linked_github_login", lookup_down)
    r = client.post("/api/v1/users/me/refresh-github")
    assert r.status_code == 503 and fetched == [] and written == [] and "unreachable" not in r.text

    monkeypatch.setattr(users_api, "linked_github_login", lambda uid: "real-login")
    r = client.post("/api/v1/users/me/refresh-github")
    assert r.status_code == 200 and r.json()["status"] == "refreshed"
    assert fetched == ["real-login"] and written[0]["followers"] == 9


def _gh(handler):
    return GitHubService(token="", transport=httpx.MockTransport(handler))


@pytest.mark.parametrize(
    "handler",
    [
        lambda r: httpx.Response(301, json={"message": "Moved Permanently", "url": "https://api.github.com/x"}),
        lambda r: httpx.Response(200, json={"message": "not a list"} if r.url.path.endswith("/repos") else {}),
        lambda r: httpx.Response(200, text="<html>maintenance</html>"),
    ],
    ids=["redirect", "wrong-shape", "not-json"],
)
def test_unexpected_github_responses_never_become_stats(handler):
    with pytest.raises(GitHubUnavailable):
        asyncio.run(_gh(handler).fetch_stats("dev"))


# ── Recommendations: only a missing profile is a 404 ────────────────────────

def test_recommendation_errors_are_not_reported_as_not_found(client, monkeypatch):
    class Broken:
        async def get_recommendations(self, **kwargs):
            # e.g. pydantic's ValidationError, which subclasses ValueError
            raise ValueError("1 validation error for UserProfile languages.1 input_value='secret'")

    monkeypatch.setattr(rec_api, "RecommendationService", Broken)
    r = client.get("/api/v1/recommendations")
    assert r.status_code == 500 and "secret" not in r.text

    class NoProfile:
        async def get_recommendations(self, **kwargs):
            raise ProfileNotFoundError("Profile not found. Open the app once to create it.")

    monkeypatch.setattr(rec_api, "RecommendationService", NoProfile)
    r = client.get("/api/v1/recommendations")
    assert r.status_code == 404 and "Profile not found" in r.json()["detail"]
