from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime

import numpy as np

from ..repositories.ml_model_repository import MlModelRepository
from ..repositories.swipe_repository import SwipeRepository
from ..repositories.user_repository import UserRepository
from .ml_features import extract_pair_features

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class TrainResult:
    model_name: str
    version: int
    trained_at: str
    n_rows: int
    n_users: int
    n_pos: int
    auc: float | None
    feature_names: list[str]


class MlTrainer:
    def __init__(
        self,
        *,
        model_repo: MlModelRepository | None = None,
        swipe_repo: SwipeRepository | None = None,
        user_repo: UserRepository | None = None,
        model_name: str = "logreg_v1",
    ):
        self._model_repo = model_repo or MlModelRepository()
        self._swipes = swipe_repo or SwipeRepository()
        self._users = user_repo or UserRepository()
        self._model_name = model_name

    def retrain(self, *, limit: int = 20000, superlike_weight: float = 3.0) -> TrainResult:
        try:
            from sklearn.linear_model import LogisticRegression
            from sklearn.metrics import roc_auc_score
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("scikit-learn is required to retrain the ML model.") from exc

        rows = [
            r for r in self._swipes.get_training_swipes(limit=limit)
            if r.get("swiper_id") and r.get("swiped_user_id") and r.get("action") in ("like", "dislike", "superLike")
        ]
        if not rows:
            raise ValueError("No swipe data available for training.")

        # Oldest first, so the chronological split trains on the past and
        # validates on the most recent behaviour (the old code had this reversed).
        rows.sort(key=lambda r: str(r.get("swiped_at") or ""))

        user_ids = list({r["swiper_id"] for r in rows} | {r["swiped_user_id"] for r in rows})
        users = {u.id: u for u in self._users.bulk_get_by_ids(user_ids)}
        cf_signal = self._swipes.get_inbound_like_counts(user_ids)
        max_cf = max(cf_signal.values(), default=1)

        X: list[list[float]] = []
        y: list[int] = []
        sample_w: list[float] = []
        feature_names: list[str] | None = None

        for r in rows:
            viewer, cand = users.get(r["swiper_id"]), users.get(r["swiped_user_id"])
            if viewer is None or cand is None:
                continue
            feats = extract_pair_features(viewer, cand, cf_count=cf_signal.get(cand.id, 0), max_cf=max_cf)
            if feature_names is None:
                feature_names = list(feats)
            X.append([float(feats[k]) for k in feature_names])
            y.append(1 if r["action"] in ("like", "superLike") else 0)
            sample_w.append(superlike_weight if r["action"] == "superLike" else 1.0)

        if not X:
            raise ValueError("No usable training rows after filtering.")

        Xn = np.asarray(X, dtype=np.float32)
        yn = np.asarray(y, dtype=np.int32)
        wn = np.asarray(sample_w, dtype=np.float32)
        if len(np.unique(yn)) < 2:
            raise ValueError("Not enough class diversity in data. Need both likes and dislikes.")

        split = max(1, int(len(yn) * 0.8))
        X_train, X_val = Xn[:split], Xn[split:]
        y_train, y_val = yn[:split], yn[split:]
        w_train, w_val = wn[:split], wn[split:]
        if len(np.unique(y_train)) < 2:
            # Tiny datasets: train on everything and skip validation.
            X_train, y_train, w_train = Xn, yn, wn
            y_val = np.asarray([], dtype=np.int32)

        clf = LogisticRegression(penalty="l2", C=1.0, solver="lbfgs", max_iter=500)
        clf.fit(X_train, y_train, sample_weight=w_train)

        auc: float | None = None
        if len(y_val) > 0 and len(np.unique(y_val)) > 1:
            auc = float(roc_auc_score(y_val, clf.predict_proba(X_val)[:, 1], sample_weight=w_val))

        trained_at = datetime.now(UTC).isoformat()
        latest = self._model_repo.get_latest_params(self._model_name)
        version = int((latest or {}).get("version") or 0) + 1
        names = feature_names or []
        self._model_repo.upsert_params(
            model_name=self._model_name,
            version=version,
            trained_at_iso=trained_at,
            weights={
                "b": float(clf.intercept_[0]),
                "w": {n: float(c) for n, c in zip(names, clf.coef_[0], strict=True)},
            },
            feature_schema={
                "model": "logistic_regression",
                "features": names,
                "label": "like_or_superlike",
                "superlike_weight": superlike_weight,
            },
        )

        n_pos = int(yn.sum())
        logger.info(
            "ML retrain complete model=%s v=%s rows=%s pos=%s auc=%s", self._model_name, version, len(yn), n_pos, auc
        )
        return TrainResult(
            model_name=self._model_name,
            version=version,
            trained_at=trained_at,
            n_rows=int(len(yn)),
            n_users=len(users),
            n_pos=n_pos,
            auc=auc,
            feature_names=names,
        )
