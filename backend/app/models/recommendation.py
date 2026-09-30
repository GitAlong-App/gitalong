from __future__ import annotations

from pydantic import BaseModel, Field


class RecommendationRequest(BaseModel):
    limit: int = Field(default=20, ge=1, le=100)
    force_refresh: bool = False


class RecommendationResponse(BaseModel):
    user_id: str
    recommendations: list[dict]
    total: int
    algorithm: str = "hybrid_cf_cbf"


class GitHubStats(BaseModel):
    username: str
    total_stars: int = 0
    total_forks: int = 0
    total_commits: int = 0
    public_repos: int = 0
    language_count: int = 0
    languages: list[str] = Field(default_factory=list)
    topics: list[str] = Field(default_factory=list)
    activity_score: float = 0.0


class ScoredCandidate(BaseModel):
    user_id: str
    username: str
    score: float
    score_breakdown: dict[str, float] = Field(default_factory=dict)
