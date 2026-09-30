-- =============================================================================
-- GitAlong — 0001 base schema
-- =============================================================================
-- Tables only. Idempotent: on an existing project (where the old root-level
-- supabase_*.sql files were applied) every statement here is a no-op.
-- Policies, grants, triggers and RPCs live in later migrations so that they
-- can be replaced wholesale without touching data.
--
-- Apply migrations in filename order (Supabase CLI: `supabase db push`, or
-- paste each file into the SQL editor in order).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Users ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL DEFAULT '',
  name TEXT,
  bio TEXT,
  avatar_url TEXT,
  location TEXT,
  company TEXT,
  website_url TEXT,
  github_url TEXT,
  followers INTEGER DEFAULT 0,
  following INTEGER DEFAULT 0,
  public_repos INTEGER DEFAULT 0,
  languages TEXT[] DEFAULT '{}',
  interests TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at TIMESTAMPTZ
);

-- ── Swipes ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.swipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  swiper_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  swiped_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  swiped_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_swipe UNIQUE (swiper_id, swiped_user_id)
);

-- ── Matches ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  users UUID[] NOT NULL,
  matched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  is_read BOOLEAN DEFAULT false
);

-- ── Messages ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'text',
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_read BOOLEAN DEFAULT false
);

-- ── GitHub cache (legacy; superseded by columns on public.users) ────────────
CREATE TABLE IF NOT EXISTS public.github_cache (
  id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  total_stars INTEGER DEFAULT 0,
  total_forks INTEGER DEFAULT 0,
  total_commits INTEGER DEFAULT 0,
  public_repos INTEGER DEFAULT 0,
  language_count INTEGER DEFAULT 0,
  languages TEXT[] DEFAULT '{}',
  topics TEXT[] DEFAULT '{}',
  activity_score NUMERIC DEFAULT 0,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Notifications ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Repo swipes (project discovery; API exists, client UI pending) ──────────
CREATE TABLE IF NOT EXISTS public.repo_swipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  repo_id BIGINT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('save', 'skip')),
  repo_full_name TEXT NOT NULL,
  repo_name TEXT NOT NULL,
  repo_owner TEXT NOT NULL,
  repo_url TEXT NOT NULL,
  repo_description TEXT,
  repo_language TEXT,
  repo_stars INTEGER DEFAULT 0,
  repo_forks INTEGER DEFAULT 0,
  swiped_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_repo_swipe UNIQUE (user_id, repo_id)
);

-- ── ML model storage ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ml_model_params (
  model_name TEXT PRIMARY KEY,
  version INTEGER NOT NULL DEFAULT 1,
  trained_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  weights JSONB NOT NULL DEFAULT '{}'::jsonb,
  feature_schema JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.ml_feature_stats (
  model_name TEXT PRIMARY KEY REFERENCES public.ml_model_params(model_name) ON DELETE CASCADE,
  stats JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS on for everything; policies are defined in the security migration.
ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.github_cache     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repo_swipes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ml_model_params  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ml_feature_stats ENABLE ROW LEVEL SECURITY;
