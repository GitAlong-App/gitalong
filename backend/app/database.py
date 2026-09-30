from functools import lru_cache

from supabase import Client, create_client

from .config import get_settings


@lru_cache
def get_supabase_client() -> Client:
    """Return a singleton Supabase client using the service role key (backend-only)."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_service_role_key)
