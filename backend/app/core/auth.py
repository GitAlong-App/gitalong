"""
JWT / Auth utilities
====================
Verifies Supabase access tokens sent as `Authorization: Bearer <token>`.

* Asymmetric keys (ES256 / RS256, current Supabase default) are verified
  against the project's JWKS endpoint.
* Legacy HS256 projects are verified with SUPABASE_JWT_SECRET when set.

Only tokens for the `authenticated` audience with a `sub` claim are accepted,
so the anon key or a service key can't be used to impersonate a user.
"""
from __future__ import annotations

import logging
from functools import lru_cache

import jwt
from fastapi import Header, HTTPException, Request, status
from jwt import PyJWKClient

from ..config import get_settings
from .rate_limit import SlidingWindowLimiter

logger = logging.getLogger(__name__)

_AUDIENCE = "authenticated"
_user_limiter = SlidingWindowLimiter(max_requests=get_settings().rate_limit_per_minute, window_seconds=60)


@lru_cache(maxsize=1)
def _get_jwk_client() -> PyJWKClient:
    settings = get_settings()
    uri = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
    return PyJWKClient(uri, cache_jwk_set=True, lifespan=600)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def decode_token(token: str) -> dict:
    """Verify a Supabase access token and return its claims."""
    settings = get_settings()
    try:
        header = jwt.get_unverified_header(token)
    except jwt.PyJWTError as exc:
        raise _unauthorized("Malformed token.") from exc

    alg = header.get("alg")
    try:
        # The key source is chosen by `alg`, and each branch accepts only its own
        # algorithms, so an HS256 token is never checked against a JWKS public key.
        if alg == "HS256":
            if not settings.supabase_jwt_secret:
                raise _unauthorized("HS256 tokens are not accepted by this server.")
            key, algorithms = settings.supabase_jwt_secret, ["HS256"]
        else:
            key, algorithms = _get_jwk_client().get_signing_key_from_jwt(token).key, ["ES256", "RS256"]
        claims = jwt.decode(
            token,
            key=key,
            algorithms=algorithms,
            audience=_AUDIENCE,
            options={"require": ["exp", "sub"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise _unauthorized("Token has expired. Please sign in again.") from exc
    except jwt.PyJWKClientConnectionError as exc:
        # Our problem, not the caller's: a 401 here would tell every client its
        # (valid) session is bad while the JWKS endpoint is unreachable.
        logger.warning("JWKS fetch failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication is temporarily unavailable. Please retry.",
            headers={"Retry-After": "5"},
        ) from exc
    except jwt.PyJWTError as exc:
        logger.info("Rejected token: %s", exc)
        raise _unauthorized("Invalid token.") from exc
    return claims


def verify_token(request: Request, authorization: str = Header(default="")) -> str:
    """
    FastAPI dependency: verifies the bearer token and returns the user's UUID.
    Also records the user id on the request so the rate limiter can key on it.
    """
    if not authorization.startswith("Bearer "):
        raise _unauthorized("Missing or malformed Authorization header.")
    claims = decode_token(authorization[7:].strip())
    user_id = str(claims["sub"])
    if not _user_limiter.hit(user_id):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please slow down.",
            headers={"Retry-After": "60"},
        )
    request.state.user_id = user_id
    return user_id
