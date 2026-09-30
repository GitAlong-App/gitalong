from datetime import UTC, datetime, timedelta

from app.services.ml_ranker import MlRanker
from app.services.ml_trainer import MlTrainer
from tests.conftest import make_user


class FakeModelRepo:
    def __init__(self):
        self.saved = None

    def get_latest_params(self, name):
        return self.saved

    def upsert_params(self, **kwargs):
        self.saved = {"version": kwargs["version"], "weights": kwargs["weights"]}
        return self.saved


def test_trainer_learns_intent_signal_and_ranker_uses_it():
    founders = [make_user(f"f{i}", looking_for=["cofounder"], languages=["Rust"]) for i in range(10)]
    hackers = [make_user(f"h{i}", looking_for=["hackathon"], languages=["Rust"]) for i in range(10)]
    viewers = [make_user(f"v{i}", looking_for=["cofounder"], languages=["Rust"]) for i in range(10)]
    users = {u.id: u for u in founders + hackers + viewers}

    t0 = datetime(2026, 1, 1, tzinfo=UTC)
    swipes = []
    for i, v in enumerate(viewers):
        for j, f in enumerate(founders):
            swipes.append({"swiper_id": v.id, "swiped_user_id": f.id, "action": "like",
                           "swiped_at": (t0 + timedelta(minutes=i * 40 + j)).isoformat()})
        for j, h in enumerate(hackers):
            swipes.append({"swiper_id": v.id, "swiped_user_id": h.id, "action": "dislike",
                           "swiped_at": (t0 + timedelta(minutes=i * 40 + 20 + j)).isoformat()})

    class Swipes:
        def get_training_swipes(self, limit):
            return list(reversed(swipes))  # repository returns newest first

        def get_inbound_like_counts(self, ids):
            return {}

    class Users:
        def bulk_get_by_ids(self, ids):
            return [users[i] for i in ids if i in users]

    model_repo = FakeModelRepo()
    result = MlTrainer(model_repo=model_repo, swipe_repo=Swipes(), user_repo=Users()).retrain()
    assert result.n_rows == 200 and result.version == 1
    assert "intent_compat" in result.feature_names
    assert model_repo.saved["weights"]["w"]["intent_compat"] > 0

    ranker = MlRanker(repo=model_repo, model_name="test_model")
    good = ranker.score_pair(viewer=viewers[0], candidate=founders[0], cf_count=0, max_cf=1)
    bad = ranker.score_pair(viewer=viewers[0], candidate=hackers[0], cf_count=0, max_cf=1)
    assert good.score > bad.score
