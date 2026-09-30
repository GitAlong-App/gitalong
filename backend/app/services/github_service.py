from __future__ import annotations

import logging
from dataclasses import dataclass, field

import httpx

from ..config import get_settings

logger = logging.getLogger(__name__)


class GitHubUnavailable(RuntimeError):
    """GitHub could not be reached or rate-limited us. Callers must not overwrite data."""


@dataclass
class GitHubStats:
    profile: dict
    followers: int
    following: int
    public_repos: int
    total_stars: int
    total_forks: int
    languages: list[str] = field(default_factory=list)   # most-used first
    topics: list[str] = field(default_factory=list)      # most frequent first


class GitHubService:
    """Reads public developer data from the GitHub REST API."""

    BASE = "https://api.github.com"

    def __init__(self, token: str | None = None, transport: httpx.AsyncBaseTransport | None = None):
        token = get_settings().github_token if token is None else token
        headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        self._headers = headers
        self._transport = transport

    async def fetch_stats(self, username: str) -> GitHubStats:
        async with httpx.AsyncClient(
            base_url=self.BASE, headers=self._headers, timeout=10.0, transport=self._transport
        ) as client:
            try:
                user_resp = await client.get(f"/users/{username}")
                repos_resp = await client.get(
                    f"/users/{username}/repos",
                    params={"per_page": 100, "sort": "pushed", "type": "owner"},
                )
            except httpx.HTTPError as exc:
                raise GitHubUnavailable(f"GitHub request failed: {exc}") from exc

        for resp in (user_resp, repos_resp):
            if resp.status_code in (403, 429):
                raise GitHubUnavailable("GitHub rate limit reached")
            # Anything but 200 (including a redirect, which httpx doesn't
            # follow) is not data; treating it as data would zero the stats.
            if resp.status_code != 200:
                raise GitHubUnavailable(f"GitHub returned {resp.status_code}")

        try:
            user = user_resp.json()
            repos_json = repos_resp.json()
        except ValueError as exc:
            raise GitHubUnavailable("GitHub returned a non-JSON body") from exc
        if not isinstance(user, dict) or not isinstance(repos_json, list):
            raise GitHubUnavailable("GitHub returned an unexpected payload")
        repos = [r for r in repos_json if isinstance(r, dict) and not r.get("fork")]

        lang_weight: dict[str, int] = {}
        topic_count: dict[str, int] = {}
        for repo in repos:
            lang = repo.get("language")
            if lang:
                # weight by stars so flagship repos count more than experiments
                lang_weight[lang] = lang_weight.get(lang, 0) + 1 + int(repo.get("stargazers_count") or 0)
            for topic in repo.get("topics") or []:
                topic_count[topic] = topic_count.get(topic, 0) + 1

        return GitHubStats(
            profile=user,
            followers=int(user.get("followers") or 0),
            following=int(user.get("following") or 0),
            public_repos=int(user.get("public_repos") or 0),
            total_stars=sum(int(r.get("stargazers_count") or 0) for r in repos),
            total_forks=sum(int(r.get("forks_count") or 0) for r in repos),
            languages=sorted(lang_weight, key=lang_weight.get, reverse=True),
            topics=sorted(topic_count, key=topic_count.get, reverse=True),
        )
