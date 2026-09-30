-- =============================================================================
-- GitAlong — 0003 security model, matching triggers, RPCs
-- =============================================================================
-- Replaces the original policy set, which allowed any signed-in user to:
--   * create a "match" with anyone and then message them (no mutual like needed)
--   * edit the content of messages sent *to* them
--   * rewrite a match's member list
--   * read every user's email address (anon key included)
--   * see who swiped on them (the paid "likes you" signal)
--   * set their own follower / repo counts to game ranking
--
-- New model
--   * Matches are created only by a trigger when a like is reciprocated,
--     serialised per pair with an advisory lock (no duplicates, no missed
--     mutual likes under concurrency). Unmatching withdraws the unmatcher's
--     like, so the other side can't recreate the match alone.
--   * Messages can only be sent inside a match you belong to, to the other
--     member, and not across a block. Previews are maintained by trigger
--     (including when the last message is deleted).
--   * Other people's profiles are read through the read-only `public_profiles`
--     view, which omits email and hides blocked users in both directions.
--   * Clients may update only the profile columns they own; GitHub-derived
--     stats are written by the backend (service role).
-- Idempotent; safe to re-run.
-- =============================================================================

-- ── 1. Drop every existing policy on the tables this migration governs ──────
DO $$
DECLARE p RECORD;
BEGIN
  FOR p IN
    SELECT policyname, tablename FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename IN ('users','swipes','matches','messages','github_cache','notifications',
                         'repo_swipes','ml_model_params','ml_feature_stats','blocks','reports')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', p.policyname, p.tablename);
  END LOOP;
END $$;

-- ── 2. Helper: is there a block between the caller and `other`? ────────────
CREATE OR REPLACE FUNCTION public.is_blocked_with(other UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.blocks
     WHERE (blocker_id = auth.uid() AND blocked_id = other)
        OR (blocker_id = other AND blocked_id = auth.uid())
  );
$$;

-- ── 3. Table privileges + policies ───────────────────────────────────────────

-- users: own row only; others via public_profiles.
REVOKE ALL ON public.users FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.users FROM authenticated;
GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE (name, bio, location, company, website_url, languages, interests,
              looking_for, seeking_skills, pitch, last_active_at)
  ON public.users TO authenticated;

CREATE POLICY users_select_own ON public.users
  FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- swipes: private to the swiper.
REVOKE ALL ON public.swipes FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.swipes TO authenticated;

CREATE POLICY swipes_select_own ON public.swipes
  FOR SELECT TO authenticated USING (swiper_id = auth.uid());
CREATE POLICY swipes_insert_own ON public.swipes
  FOR INSERT TO authenticated WITH CHECK (swiper_id = auth.uid());
CREATE POLICY swipes_update_own ON public.swipes
  FOR UPDATE TO authenticated USING (swiper_id = auth.uid()) WITH CHECK (swiper_id = auth.uid());
CREATE POLICY swipes_delete_own ON public.swipes
  FOR DELETE TO authenticated USING (swiper_id = auth.uid());

-- matches: members can read and unmatch; creation/updates are trigger-only.
REVOKE ALL ON public.matches FROM anon;
REVOKE INSERT, UPDATE ON public.matches FROM authenticated;
GRANT SELECT, DELETE ON public.matches TO authenticated;

CREATE POLICY matches_select_member ON public.matches
  FOR SELECT TO authenticated USING (auth.uid() = ANY (users));
CREATE POLICY matches_delete_member ON public.matches
  FOR DELETE TO authenticated USING (auth.uid() = ANY (users));

-- messages: send within your match only; receivers may flip is_read only.
REVOKE ALL ON public.messages FROM anon;
REVOKE UPDATE ON public.messages FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.messages TO authenticated;
GRANT UPDATE (is_read) ON public.messages TO authenticated;

CREATE POLICY messages_select_participant ON public.messages
  FOR SELECT TO authenticated USING (auth.uid() IN (sender_id, receiver_id));
CREATE POLICY messages_insert_member ON public.messages
  FOR INSERT TO authenticated WITH CHECK (
    sender_id = auth.uid()
    AND receiver_id <> sender_id
    AND EXISTS (
      SELECT 1 FROM public.matches m
       WHERE m.id = match_id
         AND sender_id = ANY (m.users)
         AND receiver_id = ANY (m.users)
    )
    AND NOT public.is_blocked_with(receiver_id)
  );
CREATE POLICY messages_update_receiver ON public.messages
  FOR UPDATE TO authenticated USING (receiver_id = auth.uid()) WITH CHECK (receiver_id = auth.uid());
CREATE POLICY messages_delete_sender ON public.messages
  FOR DELETE TO authenticated USING (sender_id = auth.uid());

-- notifications: written by triggers/backend; users read + mark read.
REVOKE ALL ON public.notifications FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.notifications FROM authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY notifications_update_own ON public.notifications
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- repo_swipes: private to the user.
REVOKE ALL ON public.repo_swipes FROM anon;
CREATE POLICY repo_swipes_select_own ON public.repo_swipes
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY repo_swipes_insert_own ON public.repo_swipes
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY repo_swipes_update_own ON public.repo_swipes
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY repo_swipes_delete_own ON public.repo_swipes
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- blocks: private to the blocker.
REVOKE ALL ON public.blocks FROM anon;
GRANT SELECT, INSERT, DELETE ON public.blocks TO authenticated;
CREATE POLICY blocks_select_own ON public.blocks
  FOR SELECT TO authenticated USING (blocker_id = auth.uid());
CREATE POLICY blocks_insert_own ON public.blocks
  FOR INSERT TO authenticated WITH CHECK (blocker_id = auth.uid());
CREATE POLICY blocks_delete_own ON public.blocks
  FOR DELETE TO authenticated USING (blocker_id = auth.uid());

-- reports: write-once by the reporter; moderation status is admin-only.
REVOKE ALL ON public.reports FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.reports FROM authenticated;
GRANT SELECT ON public.reports TO authenticated;
GRANT INSERT (reporter_id, reported_id, match_id, reason, details) ON public.reports TO authenticated;
CREATE POLICY reports_insert_own ON public.reports
  FOR INSERT TO authenticated WITH CHECK (reporter_id = auth.uid());
CREATE POLICY reports_select_own ON public.reports
  FOR SELECT TO authenticated USING (reporter_id = auth.uid());

-- Backend-only tables (no policies = no client access).
REVOKE ALL ON public.github_cache     FROM anon, authenticated;
REVOKE ALL ON public.ml_model_params  FROM anon, authenticated;
REVOKE ALL ON public.ml_feature_stats FROM anon, authenticated;

-- ── 4. Public profile directory (no email, block-aware) ─────────────────────
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles AS
SELECT u.id, u.username, u.name, u.bio, u.avatar_url, u.location, u.company,
       u.website_url, u.github_url, u.followers, u.following, u.public_repos,
       u.total_stars, u.languages, u.interests, u.github_topics, u.looking_for,
       u.seeking_skills, u.pitch, u.created_at, u.last_active_at
  FROM public.users u
 WHERE NOT EXISTS (
   SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = auth.uid() AND b.blocked_id = u.id)
       OR (b.blocker_id = u.id AND b.blocked_id = auth.uid())
 );
-- Read-only, and that matters: this is a simple (auto-updatable) view that runs
-- with its owner's rights, so any INSERT/UPDATE/DELETE privilege on it would
-- bypass RLS and the column grants on users (rewrite or delete anyone's
-- profile). Supabase's default privileges grant ALL on new views to anon and
-- authenticated, so revoke everything before granting SELECT.
REVOKE ALL ON public.public_profiles FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.public_profiles TO authenticated, service_role;

-- ── 5. Profile creation (trigger on sign-up + self-heal RPC) ────────────────
CREATE OR REPLACE FUNCTION public._create_profile_for(p_id UUID, p_email TEXT, p_meta JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  -- raw_user_meta_data is user-editable (sign-up `data`, updateUser), so it is
  -- only trusted as a GitHub login when Supabase Auth itself recorded a GitHub
  -- sign-up in raw_app_meta_data (not user-editable). Otherwise anyone could
  -- sign up by email with {"user_name": "<famous dev>"} and get their github_url.
  v_app JSONB := COALESCE((SELECT raw_app_meta_data FROM auth.users WHERE id = p_id), '{}'::JSONB);
  v_is_github BOOLEAN := COALESCE(v_app->>'provider' = 'github', false)
                         OR COALESCE(v_app->'providers', '[]'::JSONB) @> '["github"]'::JSONB;
  v_login TEXT := COALESCE(NULLIF(p_meta->>'user_name', ''), NULLIF(p_meta->>'preferred_username', ''));
  v_username TEXT := COALESCE(v_login, NULLIF(split_part(COALESCE(p_email, ''), '@', 1), ''),
                              'dev_' || left(replace(p_id::TEXT, '-', ''), 8));
  v_name TEXT := COALESCE(NULLIF(p_meta->>'full_name', ''), NULLIF(p_meta->>'name', ''));
  v_github TEXT := CASE WHEN v_is_github AND v_login IS NOT NULL THEN 'https://github.com/' || v_login END;
BEGIN
  BEGIN
    INSERT INTO public.users (id, username, email, name, avatar_url, github_url, created_at, last_active_at)
    VALUES (p_id, v_username, COALESCE(p_email, ''), v_name, p_meta->>'avatar_url', v_github, now(), now())
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN unique_violation THEN
    -- Username already taken (e.g. a renamed GitHub account); disambiguate.
    INSERT INTO public.users (id, username, email, name, avatar_url, github_url, created_at, last_active_at)
    VALUES (p_id, v_username || '_' || left(replace(p_id::TEXT, '-', ''), 6), COALESCE(p_email, ''),
            v_name, p_meta->>'avatar_url', v_github, now(), now())
    ON CONFLICT (id) DO NOTHING;
  END;
END $$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM public._create_profile_for(NEW.id, NEW.email, NEW.raw_user_meta_data);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never block sign-up; ensure_user_profile() will retry on first app load.
  RAISE WARNING 'handle_new_user failed for %: %', NEW.id, SQLERRM;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Returns the caller's profile, creating it if missing, and bumps activity.
CREATE OR REPLACE FUNCTION public.ensure_user_profile()
RETURNS public.users LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_email TEXT;
  v_meta JSONB;
  v_row public.users;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_uid) THEN
    SELECT email, raw_user_meta_data INTO v_email, v_meta FROM auth.users WHERE id = v_uid;
    PERFORM public._create_profile_for(v_uid, v_email, v_meta);
  END IF;
  UPDATE public.users SET last_active_at = now() WHERE id = v_uid RETURNING * INTO v_row;
  RETURN v_row;
END $$;

-- last_active_at is client-writable (activity pings) and feeds ranking, the
-- candidate-pool order and "Active today". Never accept a future timestamp.
CREATE OR REPLACE FUNCTION public.users_clamp_last_active()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.last_active_at > now() THEN
    NEW.last_active_at := now();
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_users_clamp_last_active ON public.users;
CREATE TRIGGER on_users_clamp_last_active
  BEFORE INSERT OR UPDATE OF last_active_at ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.users_clamp_last_active();

-- ── 6. Matching: reciprocated like → match + notification ──────────────────
CREATE OR REPLACE FUNCTION public.handle_swipe_match()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_a UUID := LEAST(NEW.swiper_id, NEW.swiped_user_id);
  v_b UUID := GREATEST(NEW.swiper_id, NEW.swiped_user_id);
  v_match_id UUID;
  v_swiper_name TEXT;
BEGIN
  IF NEW.action NOT IN ('like', 'superLike') THEN
    RETURN NEW;
  END IF;

  -- Serialise concurrent swipes on this pair. Without this, A→B and B→A
  -- committing at the same time would each miss the other's like.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_a::TEXT || ':' || v_b::TEXT, 0));

  IF NOT EXISTS (
    SELECT 1 FROM public.swipes
     WHERE swiper_id = NEW.swiped_user_id
       AND swiped_user_id = NEW.swiper_id
       AND action IN ('like', 'superLike')
  ) THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.blocks
     WHERE (blocker_id = v_a AND blocked_id = v_b) OR (blocker_id = v_b AND blocked_id = v_a)
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.matches (users) VALUES (ARRAY[v_a, v_b])
    ON CONFLICT (pair_key) DO NOTHING
    RETURNING id INTO v_match_id;

  IF v_match_id IS NULL THEN
    RETURN NEW; -- already matched
  END IF;

  -- The swiper sees the match screen immediately; notify the other person.
  SELECT COALESCE(name, username) INTO v_swiper_name FROM public.users WHERE id = NEW.swiper_id;
  INSERT INTO public.notifications (user_id, type, payload)
  VALUES (NEW.swiped_user_id, 'new_match', jsonb_build_object(
    'match_id', v_match_id,
    'from_user_id', NEW.swiper_id,
    'from_user_name', COALESCE(v_swiper_name, 'A developer')
  ));

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_swipe_match ON public.swipes;
CREATE TRIGGER on_swipe_match
  AFTER INSERT OR UPDATE ON public.swipes
  FOR EACH ROW EXECUTE FUNCTION public.handle_swipe_match();

-- Unmatching must stick. The unmatcher's like is withdrawn (turned into a
-- dislike); otherwise the other person could recreate the match — and re-open
-- the chat, with a fresh "new match" notification — just by re-sending their
-- like. Deletes by the backend (service role) have no auth.uid(); the API
-- withdraws the caller's like itself before deleting.
CREATE OR REPLACE FUNCTION public.handle_match_deleted()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_other UUID;
BEGIN
  IF v_uid IS NULL OR NOT (v_uid = ANY (OLD.users)) THEN
    RETURN OLD;
  END IF;
  v_other := CASE WHEN OLD.users[1] = v_uid THEN OLD.users[2] ELSE OLD.users[1] END;
  IF EXISTS (SELECT 1 FROM public.swipes
              WHERE swiper_id = v_uid AND swiped_user_id = v_other
                AND action IN ('like', 'superLike')) THEN
    -- Same per-pair lock as handle_swipe_match, taken before the match row is
    -- gone: a like racing this unmatch either still sees the match (no-op) or
    -- sees the withdrawn like.
    PERFORM pg_advisory_xact_lock(hashtextextended(
      LEAST(v_uid, v_other)::TEXT || ':' || GREATEST(v_uid, v_other)::TEXT, 0));
    UPDATE public.swipes SET action = 'dislike'
     WHERE swiper_id = v_uid AND swiped_user_id = v_other
       AND action IN ('like', 'superLike');
  END IF;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS on_match_deleted ON public.matches;
CREATE TRIGGER on_match_deleted
  BEFORE DELETE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.handle_match_deleted();

-- ── 7. Messages: server timestamps + match preview ──────────────────────────
CREATE OR REPLACE FUNCTION public.messages_before_insert()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  -- Enforced here rather than by a CHECK constraint, which Postgres would also
  -- re-evaluate on UPDATE: legacy messages outside the limits must still be
  -- markable as read.
  IF char_length(NEW.content) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'message content must be 1 to 4000 characters'
      USING ERRCODE = '23514';  -- check_violation
  END IF;
  NEW.sent_at := now();
  NEW.is_read := false;
  NEW.type := COALESCE(NEW.type, 'text');
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.messages_after_insert()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE public.matches
     SET last_message = left(NEW.content, 280),
         last_message_at = NEW.sent_at,
         last_message_sender_id = NEW.sender_id,
         is_read = false
   WHERE id = NEW.match_id;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_message_before_insert ON public.messages;
CREATE TRIGGER on_message_before_insert
  BEFORE INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_before_insert();

DROP TRIGGER IF EXISTS on_message_after_insert ON public.messages;
CREATE TRIGGER on_message_after_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_after_insert();

-- A message its sender deleted must not live on in the chat-list preview.
-- Rebuild the preview from the newest remaining message, but only when it
-- could be showing the deleted one. When a whole match is deleted the match
-- row is already gone, so the cascade is a cheap no-op.
CREATE OR REPLACE FUNCTION public.messages_after_delete()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_content TEXT;
  v_sent_at TIMESTAMPTZ;
  v_sender UUID;
  v_is_read BOOLEAN;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.matches
                  WHERE id = OLD.match_id
                    AND (last_message_at IS NULL OR last_message_at <= OLD.sent_at)) THEN
    RETURN OLD;
  END IF;
  SELECT content, sent_at, sender_id, is_read
    INTO v_content, v_sent_at, v_sender, v_is_read
    FROM public.messages
   WHERE match_id = OLD.match_id
   ORDER BY sent_at DESC, id DESC
   LIMIT 1;
  UPDATE public.matches
     SET last_message = left(v_content, 280),
         last_message_at = v_sent_at,
         last_message_sender_id = v_sender,
         is_read = COALESCE(v_is_read, false)
   WHERE id = OLD.match_id;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS on_message_after_delete ON public.messages;
CREATE TRIGGER on_message_after_delete
  AFTER DELETE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_after_delete();

-- ── 8. Client RPCs ───────────────────────────────────────────────────────────

-- Mark everything the caller received in a match as read.
CREATE OR REPLACE FUNCTION public.mark_match_read(p_match_id UUID)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_count INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.matches WHERE id = p_match_id AND v_uid = ANY (users)) THEN
    RAISE EXCEPTION 'not a member of this match' USING ERRCODE = '42501';
  END IF;

  UPDATE public.messages SET is_read = true
   WHERE match_id = p_match_id AND receiver_id = v_uid AND is_read = false;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  UPDATE public.matches SET is_read = true
   WHERE id = p_match_id AND is_read = false
     AND last_message_sender_id IS DISTINCT FROM v_uid;

  RETURN v_count;
END $$;

-- Block someone: hides both sides from each other and ends any match.
CREATE OR REPLACE FUNCTION public.block_user(p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_user_id IS NULL OR p_user_id = v_uid THEN
    RAISE EXCEPTION 'invalid user' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.blocks (blocker_id, blocked_id) VALUES (v_uid, p_user_id)
    ON CONFLICT DO NOTHING;
  DELETE FROM public.matches
   WHERE pair_key = LEAST(v_uid, p_user_id)::TEXT || ':' || GREATEST(v_uid, p_user_id)::TEXT;
END $$;

-- How many people are waiting on the caller's swipe (the "likes you" teaser).
CREATE OR REPLACE FUNCTION public.get_likes_received_count()
RETURNS INTEGER LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT count(*)::INTEGER
    FROM public.swipes s
   WHERE s.swiped_user_id = auth.uid()
     AND s.action IN ('like', 'superLike')
     AND NOT EXISTS (SELECT 1 FROM public.swipes r
                      WHERE r.swiper_id = auth.uid() AND r.swiped_user_id = s.swiper_id)
     AND NOT EXISTS (SELECT 1 FROM public.blocks b
                      WHERE (b.blocker_id = auth.uid() AND b.blocked_id = s.swiper_id)
                         OR (b.blocker_id = s.swiper_id AND b.blocked_id = auth.uid()));
$$;

-- Full account deletion, usable even when the backend is unreachable.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  DELETE FROM public.swipes WHERE swiper_id = v_uid;          -- (would cascade; first so unmatching has nothing to withdraw)
  DELETE FROM public.matches WHERE v_uid = ANY (users);       -- messages cascade
  DELETE FROM auth.users WHERE id = v_uid;                    -- profile + everything else cascades
END $$;

-- ── 9. Backend (service role) RPCs for recommendations ──────────────────────

-- Candidate generation done in SQL: excludes swiped/blocked users without
-- shipping the exclusion list over HTTP, and pre-orders by cheap overlap so the
-- Python ranker sees the most promising slice of the user base.
CREATE OR REPLACE FUNCTION public.get_candidate_pool(p_user_id UUID, p_limit INTEGER DEFAULT 200)
RETURNS SETOF public.users LANGUAGE sql STABLE SET search_path = '' AS $$
  WITH me AS (
    SELECT ARRAY(SELECT lower(x) FROM unnest(languages) x)                    AS langs,
           ARRAY(SELECT lower(x) FROM unnest(interests || github_topics) x)   AS topics,
           ARRAY(SELECT lower(x) FROM unnest(seeking_skills) x)               AS seeking,
           looking_for
      FROM public.users WHERE id = p_user_id
  )
  SELECT u.*
    FROM public.users u CROSS JOIN me
   WHERE u.id <> p_user_id
     AND (u.public_repos > 0 OR cardinality(u.languages) > 0
          -- someone waiting on the viewer's swipe is always eligible, even with
          -- a bare profile: they are counted by get_likes_received_count()
          OR EXISTS (SELECT 1 FROM public.swipes s
                      WHERE s.swiper_id = u.id AND s.swiped_user_id = p_user_id
                        AND s.action IN ('like', 'superLike')))
     AND NOT EXISTS (SELECT 1 FROM public.swipes s
                      WHERE s.swiper_id = p_user_id AND s.swiped_user_id = u.id)
     AND NOT EXISTS (SELECT 1 FROM public.blocks b
                      WHERE (b.blocker_id = p_user_id AND b.blocked_id = u.id)
                         OR (b.blocker_id = u.id AND b.blocked_id = p_user_id))
   ORDER BY
     -- people who already liked the viewer must be in the pool
     EXISTS (SELECT 1 FROM public.swipes s
              WHERE s.swiper_id = u.id AND s.swiped_user_id = p_user_id
                AND s.action IN ('like', 'superLike')) DESC,
     (
         cardinality(ARRAY(SELECT lower(x) FROM unnest(u.languages) x
                           INTERSECT SELECT unnest(me.langs)))
       + cardinality(ARRAY(SELECT lower(x) FROM unnest(u.interests || u.github_topics) x
                           INTERSECT SELECT unnest(me.topics)))
       + 2 * cardinality(ARRAY(SELECT lower(x) FROM unnest(u.languages) x
                               INTERSECT SELECT unnest(me.seeking)))
       + 2 * cardinality(ARRAY(SELECT x FROM unnest(u.looking_for) x
                               INTERSECT SELECT unnest(me.looking_for)))
       + 2 * ((('mentor' = ANY (me.looking_for) AND 'mentee' = ANY (u.looking_for))
            OR ('mentee' = ANY (me.looking_for) AND 'mentor' = ANY (u.looking_for)))::INTEGER)
     ) DESC,
     u.last_active_at DESC NULLS LAST
   LIMIT LEAST(GREATEST(p_limit, 1), 1000);
$$;

-- Users who liked p_user_id and are still waiting on p_user_id's swipe.
CREATE OR REPLACE FUNCTION public.get_pending_liker_ids(p_user_id UUID)
RETURNS SETOF UUID LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT s.swiper_id
    FROM public.swipes s
   WHERE s.swiped_user_id = p_user_id
     AND s.action IN ('like', 'superLike')
     AND NOT EXISTS (SELECT 1 FROM public.swipes r
                      WHERE r.swiper_id = p_user_id AND r.swiped_user_id = s.swiper_id)
     AND NOT EXISTS (SELECT 1 FROM public.blocks b
                      WHERE (b.blocker_id = p_user_id AND b.blocked_id = s.swiper_id)
                         OR (b.blocker_id = s.swiper_id AND b.blocked_id = p_user_id));
$$;

-- Distinct inbound likes per user, for the collaborative popularity signal.
CREATE OR REPLACE FUNCTION public.get_inbound_like_counts(p_user_ids UUID[])
RETURNS TABLE (user_id UUID, likes BIGINT) LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT s.swiped_user_id, count(DISTINCT s.swiper_id)
    FROM public.swipes s
   WHERE s.swiped_user_id = ANY (p_user_ids)
     AND s.action IN ('like', 'superLike')
   GROUP BY s.swiped_user_id;
$$;

-- ── 10. Function privileges ──────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.is_blocked_with(UUID)                 FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public._create_profile_for(UUID, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()                      FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_swipe_match()                   FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_match_deleted()                 FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.users_clamp_last_active()              FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.messages_before_insert()               FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.messages_after_insert()                FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.messages_after_delete()                FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_user_profile()                  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_match_read(UUID)                  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.block_user(UUID)                       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_likes_received_count()             FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.delete_my_account()                    FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_candidate_pool(UUID, INTEGER)      FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_pending_liker_ids(UUID)            FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_inbound_like_counts(UUID[])        FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.is_blocked_with(UUID)            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ensure_user_profile()            TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_match_read(UUID)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_user(UUID)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_likes_received_count()       TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account()              TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_candidate_pool(UUID, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_pending_liker_ids(UUID)       TO service_role;
GRANT EXECUTE ON FUNCTION public.get_inbound_like_counts(UUID[])   TO service_role;

-- ── 11. Realtime ─────────────────────────────────────────────────────────────
DO $$
DECLARE t TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH t IN ARRAY ARRAY['messages', 'matches', 'notifications'] LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t) THEN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
      END IF;
    END LOOP;
  END IF;
END $$;
