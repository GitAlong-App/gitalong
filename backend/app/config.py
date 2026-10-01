from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Supabase
    supabase_url: str
    supabase_anon_key: str = ""
    supabase_service_role_key: str
    # Only needed for projects still on the legacy HS256 JWT secret. Projects
    # using asymmetric signing keys are verified through the JWKS endpoint.
    supabase_jwt_secret: str = ""

    # GitHub API
    github_token: str = ""

    # App
    app_name: str = "GitAlong API"
    app_version: str = "2.0.0"
    debug: bool = False

    # CORS — website origins. Mobile apps don't send Origin, so this only
    # governs browsers (the GitAlong website).
    allowed_origins: str | list[str] = [
        "https://gitalong.app",
        "https://www.gitalong.app",
        "https://gitalong-preview.vercel.app",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ]

    @field_validator("allowed_origins", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",") if i.strip()]
        return v

    # Rate limiting (per authenticated user, falling back to client IP)
    rate_limit_per_minute: int = 120

    # Recommendation engine
    recommendation_limit: int = 20
    candidate_pool_size: int = 200

    # ML ranking
    ml_ranking_enabled: bool = False
    ml_model_name: str = "logreg_v1"

    # Admin / ops
    admin_retrain_secret: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()
