"""Request-value checks shared by the routers."""
from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import HTTPException, status


def uuid_or_404(value: str, detail: str) -> str:
    """
    The canonical (lower-case) form of a UUID path parameter, or 404.

    A malformed id names nothing, so it is "not found" — rather than a 500
    from Postgres' uuid parser. It also keeps arbitrary text out of the
    PostgREST filter strings the id is interpolated into.
    """
    try:
        return str(UUID(value))
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail) from None


def timestamp_cursor(value: str | None) -> str | None:
    """Validate an ISO-8601 pagination cursor (422 instead of a database error)."""
    if value is None:
        return None
    try:
        datetime.fromisoformat(value)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid 'before' cursor: expected an ISO-8601 timestamp.",
        ) from None
    return value
