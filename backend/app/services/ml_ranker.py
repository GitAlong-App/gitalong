from __future__ import annotations

import math
import time
from dataclasses import dataclass

from ..models.user import UserProfile
from ..repositories.ml_model_repository import MlModelRepository
from .ml_features import extract_pair_features

_PARAMS_TTL_SECONDS = 300
_params_cache: dict[str, tuple[float, dict | None]] = {}


def _sigmoid(z: float) -> float:
    if z >= 0:
        return 1.0 / (1.0 + math.exp(-z))
    ez = math.exp(z)
    return ez / (1.0 + ez)


@dataclass(frozen=True)
class MlRankResult:
    score: float
    top_reasons: list[str]
    contributions: dict[str, float]


class MlRanker:
    """
    Inference for the logistic-regression ranker stored in Supabase.
    Weights are fetched once and cached for a few minutes (they only change on
    retrain) instead of one DB round-trip per candidate.
    """

    def __init__(self, *, repo: MlModelRepository | None = None, model_name: str = "logreg_v1"):
        self._repo = repo or MlModelRepository()
        self._model_name = model_name
        self._params = self._load_params()

    def _load_params(self) -> dict | None:
        now = time.monotonic()
        cached = _params_cache.get(self._model_name)
        if cached and now - cached[0] < _PARAMS_TTL_SECONDS:
            return cached[1]
        params = self._repo.get_latest_params(self._model_name)
        _params_cache[self._model_name] = (now, params)
        return params

    @property
    def available(self) -> bool:
        return bool(self._params and (self._params.get("weights") or {}).get("w"))

    def score_pair(
        self, *, viewer: UserProfile, candidate: UserProfile, cf_count: int, max_cf: int
    ) -> MlRankResult | None:
        if not self.available:
            return None
        weights = self._params["weights"]
        w_map: dict[str, float] = weights.get("w") or {}
        z = float(weights.get("b", 0.0))

        contributions: dict[str, float] = {}
        for k, v in extract_pair_features(viewer, candidate, cf_count=cf_count, max_cf=max_cf).items():
            c = float(w_map.get(k, 0.0)) * float(v)
            contributions[k] = c
            z += c

        ranked = sorted(
            ((k, c) for k, c in contributions.items() if k != "bias"), key=lambda kv: kv[1], reverse=True
        )
        return MlRankResult(
            score=_sigmoid(z),
            top_reasons=[k for k, c in ranked[:3] if c > 0],
            contributions=contributions,
        )
