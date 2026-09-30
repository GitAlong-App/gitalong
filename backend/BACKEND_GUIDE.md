# GitAlong backend — file-by-file guide

FastAPI service for **ranking** and **GitHub sync**. Core loops (profiles,
swipes, matches, chat, safety) run directly against Supabase under row-level
security (see `docs/API_AND_DATA_CONTRACT.md`). This service uses the
**service-role key**, which bypasses RLS, so every query here must scope itself
deliberately.

## Application
| File | Role |
|---|---|
| `app/main.py` | App factory: CORS (explicit website origins), per-IP rate limit, error middleware that logs details and returns generic 500s *with* CORS headers, router mount |
| `app/config.py` | `pydantic-settings` config loaded from env / `.env` |
| `app/database.py` | Cached Supabase client (service role) |
| `app/core/auth.py` | Verifies Supabase access tokens: JWKS (ES256/RS256) or legacy HS256, `aud=authenticated`, requires `sub`. Also applies the per-user rate limit |
| `app/core/rate_limit.py` | In-process sliding-window limiter (swap for Redis when scaling out) |

## API (`/api/v1`)
| File | Endpoints |
|---|---|
| `health.py` | `GET /health`: liveness + DB probe, no internal details |
| `recommendations.py` | `GET /recommendations`: ranked, explained collaborators |
| `users.py` | `GET /users/me`, `GET /users/{id}` (public, block-aware), `POST /users/me/refresh-github`, `GET /users/me/likes-received`, `DELETE /users/me` |
| `swipes.py` | `POST /swipes` (upsert; the DB trigger creates matches), `GET /swipes/history` |
| `matches.py` | `GET /matches` (per-user unread), `GET/DELETE /matches/{id}` |
| `messages.py` | `GET/POST /matches/{id}/messages`, `PUT /matches/{id}/messages/read` |
| `repo_swipes.py` | Project discovery save/skip (used by the website) |
| `admin_ml.py` | `POST /admin/retrain-ml`, `GET /admin/metrics` (`X-Admin-Secret`, constant-time compare) |
| `notifications.py` | `POST /notify-match`: deprecated no-op kept for old builds |

## Services
| File | Role |
|---|---|
| `services/collab.py` | Intent vocabulary, intent compatibility, skill complementarity, human-readable match reasons. Pure functions |
| `services/heavy_recommendation_engine.py` | Eight-signal hybrid scorer |
| `services/recommendation_service.py` | Pipeline: SQL candidate pool → scoring → optional ML → filters → liker interleave → reasons |
| `services/ml_features.py` / `ml_ranker.py` / `ml_trainer.py` | Logistic-regression re-ranker (see `MATCHING_RANKING_ML_EXPLAINED.md`) |
| `services/github_service.py` | GitHub REST client. Raises `GitHubUnavailable` instead of returning zeros, so a rate limit can never wipe profile data |

## Repositories
Thin data-access classes over Supabase: `user_repository.py` (incl. the
`get_candidate_pool` RPC and the GitHub-stats writer that never overwrites
user-curated fields), `swipe_repository.py`, `match_repository.py` (`pair_key`,
per-user unread rule), `message_repository.py`, `ml_model_repository.py`,
`repo_swipe_repository.py`.

## Running and testing
```bash
cp .env.example .env
pip install -r requirements-dev.txt
uvicorn app.main:app --reload     # http://localhost:8000/docs
ruff check app tests && pytest
```
Docker: `docker compose up`. Production: `render.yaml` at the repo root.
