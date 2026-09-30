-- =============================================================
-- GitAlong Repo Swipe Persistence
-- Run this in Supabase SQL Editor
-- =============================================================

CREATE TABLE IF NOT EXISTS public.repo_swipes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
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
  swiped_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_repo_swipe UNIQUE (user_id, repo_id)
);

CREATE INDEX IF NOT EXISTS idx_repo_swipes_user_id ON public.repo_swipes(user_id);
CREATE INDEX IF NOT EXISTS idx_repo_swipes_user_action ON public.repo_swipes(user_id, action);
CREATE INDEX IF NOT EXISTS idx_repo_swipes_swiped_at ON public.repo_swipes(swiped_at DESC);

ALTER TABLE public.repo_swipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable insert for own repo swipes" ON public.repo_swipes;
CREATE POLICY "Enable insert for own repo swipes"
ON public.repo_swipes
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Enable read for own repo swipes" ON public.repo_swipes;
CREATE POLICY "Enable read for own repo swipes"
ON public.repo_swipes
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Enable update for own repo swipes" ON public.repo_swipes;
CREATE POLICY "Enable update for own repo swipes"
ON public.repo_swipes
FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Enable delete for own repo swipes" ON public.repo_swipes;
CREATE POLICY "Enable delete for own repo swipes"
ON public.repo_swipes
FOR DELETE
USING (auth.uid() = user_id);

