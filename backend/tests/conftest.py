import os
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

# Settings are read at import time; give them harmless values before importing the app.
os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "service")
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-secret-that-is-long-enough-for-hs256-signing")
os.environ.setdefault("ADMIN_RETRAIN_SECRET", "admin-secret")
os.environ.setdefault("RATE_LIMIT_PER_MINUTE", "1000")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.models.user import UserProfile  # noqa: E402


def make_user(uid: str, **overrides) -> UserProfile:
    base = dict(
        id=uid,
        username=f"user_{uid}",
        email=f"{uid}@example.com",
        created_at=datetime.now(UTC) - timedelta(days=30),
        last_active_at=datetime.now(UTC),
        languages=[],
        interests=[],
        public_repos=5,
        followers=10,
    )
    base.update(overrides)
    return UserProfile(**base)


@pytest.fixture
def user_factory():
    return make_user


def pgrst(handler):
    """
    A real postgrest-py client whose HTTP requests go to `handler` instead of
    the network, so repository tests can assert on the exact PostgREST query.
    """
    import httpx
    from postgrest import SyncPostgrestClient
    from postgrest.utils import SyncClient

    client = SyncPostgrestClient("http://pgrst.test")
    client.session = SyncClient(base_url="http://pgrst.test", transport=httpx.MockTransport(handler))
    return client
