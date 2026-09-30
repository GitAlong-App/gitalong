import logging
import re

from fastapi import APIRouter, Depends, HTTPException, status

from ...core.auth import verify_token
from ...database import get_supabase_client
from ...models.user import PublicProfile, UserProfile
from ...repositories.swipe_repository import SwipeRepository
from ...repositories.user_repository import UserRepository
from ...services.github_service import GitHubService, GitHubUnavailable
from ._validation import uuid_or_404

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["users"])

# GitHub logins: letters, digits and hyphens, at most 39 characters (legacy
# accounts may have doubled or trailing hyphens). Anything else never reaches
# the GitHub API URL.
_GITHUB_LOGIN = re.compile(r"[A-Za-z0-9][A-Za-z0-9-]{0,38}")


def linked_github_login(user_id: str) -> str | None:
    """
    The login of the GitHub account the user signed in with, read from their
    Supabase Auth identity (written by Supabase from GitHub's OAuth response;
    users cannot edit it). None when no GitHub identity is linked.

    Never derived from `username` or user metadata: for Google/Apple/email
    accounts those come from the email address or from user-editable data, and
    using them attached a stranger's GitHub account (followers, stars, bio) to
    the profile.
    """
    user = get_supabase_client().auth.admin.get_user_by_id(user_id).user
    for identity in user.identities or []:
        if identity.provider != "github":
            continue
        data = identity.identity_data or {}
        for key in ("user_name", "preferred_username"):
            login = data.get(key)
            if isinstance(login, str) and _GITHUB_LOGIN.fullmatch(login):
                return login
    return None


@router.get("/me", response_model=UserProfile)
async def get_me(user_id: str = Depends(verify_token)):
    """The caller's full profile (the only place email is returned)."""
    profile = UserRepository().get_by_id(user_id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found.")
    return profile


@router.get("/me/likes-received")
async def likes_received(user_id: str = Depends(verify_token)):
    """How many people are waiting on the caller's swipe. Never reveals who."""
    return {"count": len(SwipeRepository().get_pending_liker_ids(user_id))}


@router.post("/me/refresh-github")
async def refresh_github_stats(user_id: str = Depends(verify_token)):
    """
    Pull fresh public stats from GitHub. GitHub-derived columns are owned by
    the backend; user-curated fields are only filled when empty. If GitHub is
    unreachable or rate-limited nothing is overwritten. Accounts without a
    linked GitHub identity get 409 and nothing is fetched or written.
    """
    repo = UserRepository()
    profile = repo.get_by_id(user_id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found.")

    try:
        login = linked_github_login(user_id)
    except Exception as exc:
        logger.warning("GitHub identity lookup failed for %s: %s", user_id, exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Couldn't verify your GitHub account right now. Your profile was not changed.",
        ) from exc
    if login is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No GitHub account is linked to this profile. Sign in with GitHub to sync your stats.",
        )

    try:
        stats = await GitHubService().fetch_stats(login)
    except GitHubUnavailable as exc:
        logger.warning("GitHub refresh skipped for %s: %s", user_id, exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GitHub is unavailable right now. Your profile was not changed.",
        ) from exc

    updated = repo.update_github_stats(
        user_id,
        followers=stats.followers,
        following=stats.following,
        public_repos=stats.public_repos,
        total_stars=stats.total_stars,
        topics=stats.topics,
        detected_languages=stats.languages,
        profile=stats.profile,
    )
    return {"status": "refreshed", "profile": updated}


@router.get("/{other_id}", response_model=PublicProfile)
async def get_user(other_id: str, user_id: str = Depends(verify_token)):
    """Another user's public profile (no email). Hidden across blocks."""
    # Validated before it is interpolated into the PostgREST `or` filter below.
    other_id = uuid_or_404(other_id, "User not found.")
    db = get_supabase_client()
    blocked = (
        db.table("blocks")
        .select("blocker_id")
        .or_(
            f"and(blocker_id.eq.{user_id},blocked_id.eq.{other_id}),"
            f"and(blocker_id.eq.{other_id},blocked_id.eq.{user_id})"
        )
        .limit(1)
        .execute()
    )
    profile = UserRepository().get_by_id(other_id)
    if profile is None or blocked.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    return profile.to_public()


@router.delete("/me", status_code=status.HTTP_200_OK)
async def delete_account(user_id: str = Depends(verify_token)):
    """
    Permanently delete the caller. Deleting the auth user cascades to the
    profile, swipes, messages, blocks, reports, repo swipes and notifications;
    matches (an array column) are removed explicitly first.
    """
    db = get_supabase_client()
    try:
        db.table("matches").delete().contains("users", [user_id]).execute()
        db.auth.admin.delete_user(user_id)
    except Exception as exc:
        logger.exception("Account deletion failed for %s", user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Account deletion failed. Please try again or contact support.",
        ) from exc
    logger.info("Account deleted for %s", user_id)
    return {"status": "deleted"}
