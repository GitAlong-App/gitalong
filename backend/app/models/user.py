from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _none_to_empty_list(v):
    # Array columns are client-writable and Postgres happily stores NULL
    # elements (e.g. `languages = ['Rust', NULL]`). One such row must not make
    # every response that includes that user fail validation, so keep only
    # the string elements (the web client does the same).
    if v is None:
        return []
    if isinstance(v, list | tuple):
        return [x for x in v if isinstance(x, str)]
    return v


class UserProfile(BaseModel):
    """A row of public.users as seen by the backend (service role)."""

    model_config = ConfigDict(from_attributes=True, extra="ignore")

    id: str
    username: str
    email: str = ""
    name: str | None = None
    bio: str | None = None
    avatar_url: str | None = None
    location: str | None = None
    company: str | None = None
    website_url: str | None = None
    github_url: str | None = None
    followers: int = 0
    following: int = 0
    public_repos: int = 0
    total_stars: int = 0
    languages: list[str] = Field(default_factory=list)
    interests: list[str] = Field(default_factory=list)
    github_topics: list[str] = Field(default_factory=list)
    looking_for: list[str] = Field(default_factory=list)
    seeking_skills: list[str] = Field(default_factory=list)
    pitch: str | None = None
    created_at: datetime
    last_active_at: datetime | None = None

    @field_validator("languages", "interests", "github_topics", "looking_for", "seeking_skills", mode="before")
    @classmethod
    def _none_to_list(cls, v):
        return _none_to_empty_list(v)

    @field_validator("followers", "following", "public_repos", "total_stars", mode="before")
    @classmethod
    def _none_to_zero(cls, v):
        return 0 if v is None else v

    def to_public(self) -> PublicProfile:
        return PublicProfile(**self.model_dump(exclude={"email"}))


class PublicProfile(BaseModel):
    """What one user may see about another. Never includes email."""

    model_config = ConfigDict(extra="ignore")

    id: str
    username: str
    name: str | None = None
    bio: str | None = None
    avatar_url: str | None = None
    location: str | None = None
    company: str | None = None
    website_url: str | None = None
    github_url: str | None = None
    followers: int = 0
    following: int = 0
    public_repos: int = 0
    total_stars: int = 0
    languages: list[str] = Field(default_factory=list)
    interests: list[str] = Field(default_factory=list)
    github_topics: list[str] = Field(default_factory=list)
    looking_for: list[str] = Field(default_factory=list)
    seeking_skills: list[str] = Field(default_factory=list)
    pitch: str | None = None
    created_at: datetime
    last_active_at: datetime | None = None
