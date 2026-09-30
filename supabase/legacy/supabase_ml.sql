-- =============================================================
-- GitAlong ML tables (MVP)
-- =============================================================
-- Purpose:
-- - Store lightweight model parameters for the recommendation ranker
-- - Keep everything Supabase/Postgres-only (no external model store)
--
-- Apply in Supabase SQL editor after base schema.
-- =============================================================

-- Stores the latest parameters for a named model.
-- We keep weights in JSONB for flexibility and easy iteration.
CREATE TABLE IF NOT EXISTS public.ml_model_params (
  model_name TEXT PRIMARY KEY,
  version INTEGER NOT NULL DEFAULT 1,
  trained_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  weights JSONB NOT NULL DEFAULT '{}'::jsonb,
  feature_schema JSONB NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE public.ml_model_params ENABLE ROW LEVEL SECURITY;

-- Read access is allowed (weights are not sensitive, but may be considered internal).
CREATE POLICY "Enable read access for all users" ON public.ml_model_params
  FOR SELECT USING (true);

-- Writes should only be done by the backend (service role).
-- If you want to allow authenticated writes, replace this with an auth.uid()-based policy.
CREATE POLICY "Disable writes from clients" ON public.ml_model_params
  FOR ALL USING (false) WITH CHECK (false);

-- Optional normalization stats (means/stds) for features if you add them later.
CREATE TABLE IF NOT EXISTS public.ml_feature_stats (
  model_name TEXT PRIMARY KEY REFERENCES public.ml_model_params(model_name) ON DELETE CASCADE,
  stats JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.ml_feature_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.ml_feature_stats
  FOR SELECT USING (true);
CREATE POLICY "Disable writes from clients" ON public.ml_feature_stats
  FOR ALL USING (false) WITH CHECK (false);

