-- =============================================================================
-- GitAlong — 0002 collaboration schema + data integrity
-- =============================================================================
-- * Collaboration intent on profiles (looking_for, seeking_skills, pitch)
-- * GitHub proof-of-work columns maintained by the backend
-- * Safety: blocks + reports
-- * Integrity: FK cascades, CHECK constraints, one match per pair, indexes
-- Idempotent; safe to re-run.
-- =============================================================================

-- ── Profile: collaboration intent + proof of work ───────────────────────────
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS looking_for     TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS seeking_skills  TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS pitch           TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_stars     INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS github_topics   TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS github_synced_at TIMESTAMPTZ;

UPDATE public.users SET languages = '{}' WHERE languages IS NULL;
UPDATE public.users SET interests = '{}' WHERE interests IS NULL;
ALTER TABLE public.users ALTER COLUMN languages SET NOT NULL;
ALTER TABLE public.users ALTER COLUMN interests SET NOT NULL;

-- The old policies let clients write last_active_at freely; a future value
-- pins a profile to the top of every deck ("Active today" forever). New
-- writes are clamped by a trigger in the security migration.
UPDATE public.users SET last_active_at = now() WHERE last_active_at > now();

DO $$ BEGIN
  ALTER TABLE public.users ADD CONSTRAINT users_pitch_len CHECK (pitch IS NULL OR char_length(pitch) <= 280);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.users ADD CONSTRAINT users_looking_for_valid CHECK (
    looking_for <@ ARRAY['cofounder','side_project','open_source','hackathon','mentor','mentee']::TEXT[]
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Deleting an auth user must cascade to the profile (it did not originally,
-- which made account deletion fail with an FK violation).
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_id_fkey;
ALTER TABLE public.users
  ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.github_cache DROP CONSTRAINT IF EXISTS github_cache_id_fkey;
ALTER TABLE public.github_cache
  ADD CONSTRAINT github_cache_id_fkey FOREIGN KEY (id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ── Swipes ───────────────────────────────────────────────────────────────────
DELETE FROM public.swipes WHERE swiper_id IS NULL OR swiped_user_id IS NULL OR swiper_id = swiped_user_id;
ALTER TABLE public.swipes ALTER COLUMN swiper_id SET NOT NULL;
ALTER TABLE public.swipes ALTER COLUMN swiped_user_id SET NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.swipes ADD CONSTRAINT swipes_action_valid
    CHECK (action IN ('like', 'dislike', 'superLike')) NOT VALID;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.swipes ADD CONSTRAINT swipes_not_self CHECK (swiper_id <> swiped_user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_swipes_swiped_user ON public.swipes (swiped_user_id, action);
CREATE INDEX IF NOT EXISTS idx_swipes_swiped_at   ON public.swipes (swiped_at DESC);

-- ── Matches: exactly one row per unordered pair ─────────────────────────────
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS last_message_sender_id UUID;

DELETE FROM public.matches
  WHERE array_length(users, 1) IS DISTINCT FROM 2 OR users[1] IS NULL OR users[2] IS NULL OR users[1] = users[2];

-- Normalise pair order so the generated key below is stable.
UPDATE public.matches
   SET users = ARRAY[LEAST(users[1], users[2]), GREATEST(users[1], users[2])]
 WHERE users[1] > users[2];

-- The old client and backend could both create a match for the same pair.
-- Keep the earliest, move messages onto it, drop the rest.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT id, keeper FROM (
      SELECT id,
             first_value(id) OVER (PARTITION BY users[1], users[2] ORDER BY matched_at, id) AS keeper
        FROM public.matches
    ) t WHERE id <> keeper
  LOOP
    UPDATE public.messages SET match_id = r.keeper WHERE match_id = r.id;
    DELETE FROM public.matches WHERE id = r.id;
  END LOOP;
END $$;

DO $$ BEGIN
  ALTER TABLE public.matches ADD CONSTRAINT matches_two_users CHECK (
    array_length(users, 1) = 2 AND users[1] IS NOT NULL AND users[2] IS NOT NULL AND users[1] <> users[2]
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS pair_key TEXT
  GENERATED ALWAYS AS (LEAST(users[1], users[2])::TEXT || ':' || GREATEST(users[1], users[2])::TEXT) STORED;

CREATE UNIQUE INDEX IF NOT EXISTS uq_matches_pair_key ON public.matches (pair_key);
CREATE INDEX IF NOT EXISTS idx_matches_users_gin ON public.matches USING GIN (users);
CREATE INDEX IF NOT EXISTS idx_matches_matched_at ON public.matches (matched_at DESC);

-- Old clients never recorded who wrote last, and the de-duplication above can
-- leave a kept match with a stale preview. Rebuild those previews from the
-- newest message so per-user unread state (last_message_sender_id) is right
-- from day one. Matches already maintained by the new trigger are untouched.
UPDATE public.matches m
   SET last_message = left(x.content, 280),
       last_message_at = x.sent_at,
       last_message_sender_id = x.sender_id,
       is_read = COALESCE(x.is_read, false)
  FROM (SELECT DISTINCT ON (match_id) match_id, content, sent_at, sender_id, is_read
          FROM public.messages
         WHERE match_id IS NOT NULL
         ORDER BY match_id, sent_at DESC, id DESC) x
 WHERE x.match_id = m.id
   AND m.last_message_sender_id IS NULL;

-- ── Messages ─────────────────────────────────────────────────────────────────
-- Content length (1..4000) is enforced on INSERT by messages_before_insert()
-- in the security migration, not by a CHECK constraint: Postgres re-checks a
-- CHECK (even a NOT VALID one) on every UPDATE of a row, so a legacy message
-- outside the limits could never be marked read.
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_content_len;

DO $$ BEGIN
  ALTER TABLE public.messages ADD CONSTRAINT messages_type_valid
    CHECK (type IN ('text', 'image', 'link', 'code')) NOT VALID;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_messages_match_sent ON public.messages (match_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages (receiver_id, match_id) WHERE is_read = false;

-- ── Notifications ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read_at ON public.notifications (user_id, read_at);

-- ── Repo swipes ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_repo_swipes_user_id ON public.repo_swipes (user_id);
CREATE INDEX IF NOT EXISTS idx_repo_swipes_user_action ON public.repo_swipes (user_id, action);
CREATE INDEX IF NOT EXISTS idx_repo_swipes_swiped_at ON public.repo_swipes (swiped_at DESC);

-- ── Safety: blocks + reports (required for app-store UGC review) ────────────
CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT blocks_not_self CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON public.blocks (blocked_id);

CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reported_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  match_id UUID REFERENCES public.matches(id) ON DELETE SET NULL,
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'fake_profile', 'other')),
  details TEXT CHECK (details IS NULL OR char_length(details) <= 1000),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'actioned', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports (status, created_at DESC);

ALTER TABLE public.blocks  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
