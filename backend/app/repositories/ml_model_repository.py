from __future__ import annotations

from postgrest.exceptions import APIError
from supabase import Client

from ..database import get_supabase_client


class MlModelRepository:
    """DAO for public.ml_model_params and public.ml_feature_stats."""

    def __init__(self, client: Client | None = None):
        self._db: Client = client or get_supabase_client()

    def get_latest_params(self, model_name: str) -> dict | None:
        try:
            resp = (
                self._db.table("ml_model_params")
                .select("*")
                .eq("model_name", model_name)
                .limit(1)
                .execute()
            )
        except APIError as exc:
            # In some postgrest-py versions, empty-object responses can surface as 204.
            if "204" in str(exc):
                return None
            raise
        if resp is None:
            return None
        rows = resp.data or []
        return rows[0] if rows else None

    def upsert_params(
        self,
        *,
        model_name: str,
        version: int,
        trained_at_iso: str,
        weights: dict,
        feature_schema: dict,
    ) -> dict:
        payload = {
            "model_name": model_name,
            "version": version,
            "trained_at": trained_at_iso,
            "weights": weights,
            "feature_schema": feature_schema,
        }
        resp = (
            self._db.table("ml_model_params")
            .upsert(payload, on_conflict="model_name")
            .execute()
        )
        if resp is None:
            return payload
        return resp.data[0] if resp.data else payload

