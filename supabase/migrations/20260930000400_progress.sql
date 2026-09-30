-- =============================================================================
-- GitAlong — 0005 progress: streaks, daily goal, XP, levels, achievements
-- =============================================================================
-- One RPC, get_my_progress(), computes everything from real activity so the
-- mobile app and the website always agree (see docs/DESIGN_SYSTEM.md §6).
-- Swipe timestamps become server-set so streaks/XP can't be faked by
-- backdating, and metrics/ML ordering can't be polluted.
-- Idempotent; safe to re-run.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_swipes_swiper_time   ON public.swipes (swiper_id, swiped_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender_time ON public.messages (sender_id, sent_at);

-- ── Server-owned swipe time ─────────────────────────────────────────────────
-- Insert → now(). Changing the decision (e.g. dislike → like) → now().
-- Any other update keeps the original time (clients can't rewrite history).
CREATE OR REPLACE FUNCTION public.swipes_server_time()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.action IS DISTINCT FROM OLD.action THEN
    NEW.swiped_at := now();
  ELSE
    NEW.swiped_at := OLD.swiped_at;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_swipe_server_time ON public.swipes;
CREATE TRIGGER on_swipe_server_time
  BEFORE INSERT OR UPDATE ON public.swipes
  FOR EACH ROW EXECUTE FUNCTION public.swipes_server_time();

-- ── get_my_progress ─────────────────────────────────────────────────────────
-- p_tz_offset_minutes: the device's UTC offset (IST = 330, PST = -480), clamped
-- to ±14 h, so "today" and streak days follow the user's calendar.
CREATE OR REPLACE FUNCTION public.get_my_progress(p_tz_offset_minutes INTEGER DEFAULT 0)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  v_uid           UUID := auth.uid();
  v_goal CONSTANT INTEGER := 10;
  v_off           INTERVAL;
  v_today         DATE;
  v_days          DATE[];
  v_total_swipes  INTEGER := 0;
  v_swipe_xp      INTEGER := 0;
  v_goal_days     INTEGER := 0;
  v_today_swipes  INTEGER := 0;
  v_messages_sent INTEGER := 0;
  v_msg_xp        INTEGER := 0;
  v_matches       INTEGER := 0;
  v_started       INTEGER := 0;
  v_qualified     INTEGER := 0;
  v_best          INTEGER := 0;
  v_current       INTEGER := 0;
  v_complete      BOOLEAN := false;
  v_xp            INTEGER;
  v_level         INTEGER;
  v_week          JSONB;
  v_ach           TEXT[] := '{}';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  v_off   := make_interval(mins => LEAST(GREATEST(COALESCE(p_tz_offset_minutes, 0), -840), 840));
  v_today := ((now() AT TIME ZONE 'UTC') + v_off)::DATE;

  -- Swipes per local day (XP counts at most 50 swipes a day).
  SELECT COALESCE(sum(n), 0),
         COALESCE(sum(LEAST(n, 50)), 0),
         COALESCE(sum(CASE WHEN n >= v_goal THEN 1 ELSE 0 END), 0),
         COALESCE(max(CASE WHEN d = v_today THEN n END), 0)
    INTO v_total_swipes, v_swipe_xp, v_goal_days, v_today_swipes
    FROM (SELECT ((s.swiped_at AT TIME ZONE 'UTC') + v_off)::DATE AS d, count(*)::INTEGER AS n
            FROM public.swipes s
           WHERE s.swiper_id = v_uid
           GROUP BY 1) per_day
   WHERE d <= v_today;

  -- Messages per local day (XP: 2 per message, at most 20 messages a day).
  SELECT COALESCE(sum(n), 0), COALESCE(sum(LEAST(n, 20)), 0) * 2
    INTO v_messages_sent, v_msg_xp
    FROM (SELECT ((m.sent_at AT TIME ZONE 'UTC') + v_off)::DATE AS d, count(*)::INTEGER AS n
            FROM public.messages m
           WHERE m.sender_id = v_uid
           GROUP BY 1) per_day
   WHERE d <= v_today;

  -- Activity days = days with a swipe or a sent message.
  v_days := ARRAY(
    SELECT DISTINCT d FROM (
      SELECT ((s.swiped_at AT TIME ZONE 'UTC') + v_off)::DATE AS d FROM public.swipes s WHERE s.swiper_id = v_uid
      UNION
      SELECT ((m.sent_at AT TIME ZONE 'UTC') + v_off)::DATE FROM public.messages m WHERE m.sender_id = v_uid
    ) a
    WHERE d <= v_today
    ORDER BY d
  );

  -- Streaks: islands of consecutive days. The current streak is the island
  -- ending today, or yesterday (still alive until the day is over).
  WITH islands AS (
    SELECT max(d) AS end_d, count(*)::INTEGER AS len
      FROM (SELECT d, d - (row_number() OVER (ORDER BY d))::INTEGER AS grp
              FROM unnest(v_days) AS d) t
     GROUP BY grp
  )
  SELECT COALESCE(max(len), 0),
         COALESCE(max(len) FILTER (WHERE end_d >= v_today - 1), 0)
    INTO v_best, v_current
    FROM islands;

  SELECT count(*)::INTEGER INTO v_matches FROM public.matches x WHERE v_uid = ANY (x.users);

  -- Conversations the caller started (sent the first message of the match).
  SELECT count(*)::INTEGER INTO v_started
    FROM (SELECT DISTINCT ON (m.match_id) m.sender_id
            FROM public.messages m
            JOIN public.matches x ON x.id = m.match_id
           WHERE v_uid = ANY (x.users)
           ORDER BY m.match_id, m.sent_at, m.id) first_msg
   WHERE first_msg.sender_id = v_uid;

  -- Qualified conversations: both people wrote and the thread has ≥ 6 messages.
  SELECT count(*)::INTEGER INTO v_qualified
    FROM (SELECT m.match_id
            FROM public.messages m
            JOIN public.matches x ON x.id = m.match_id
           WHERE v_uid = ANY (x.users)
           GROUP BY m.match_id
          HAVING count(*) >= 6 AND count(DISTINCT m.sender_id) = 2) q;

  -- Profile completeness: the same 8 checks the clients show.
  SELECT COALESCE(btrim(u.avatar_url), '') <> ''
     AND COALESCE(btrim(u.bio), '') <> ''
     AND COALESCE(btrim(u.pitch), '') <> ''
     AND cardinality(u.looking_for) > 0
     AND cardinality(u.languages) > 0
     AND cardinality(u.interests) > 0
     AND cardinality(u.seeking_skills) > 0
     AND COALESCE(btrim(u.location), '') <> ''
    INTO v_complete
    FROM public.users u WHERE u.id = v_uid;
  v_complete := COALESCE(v_complete, false);

  v_xp := v_swipe_xp + v_msg_xp + 10 * v_matches + 15 * v_started + CASE WHEN v_complete THEN 50 ELSE 0 END;
  v_level := floor(sqrt(v_xp / 50.0))::INTEGER + 1;

  SELECT jsonb_agg((g.d = ANY (v_days)) ORDER BY g.d)
    INTO v_week
    FROM (SELECT v_today - i AS d FROM generate_series(0, 6) AS i) g;

  IF v_total_swipes >= 1  THEN v_ach := v_ach || 'first_swipe'::TEXT;      END IF;
  IF v_total_swipes >= 50 THEN v_ach := v_ach || 'explorer_50'::TEXT;      END IF;
  IF v_matches >= 1       THEN v_ach := v_ach || 'first_match'::TEXT;      END IF;
  IF v_matches >= 10      THEN v_ach := v_ach || 'matches_10'::TEXT;       END IF;
  IF v_started >= 1       THEN v_ach := v_ach || 'icebreaker'::TEXT;       END IF;
  IF v_qualified >= 1     THEN v_ach := v_ach || 'real_talk'::TEXT;        END IF;
  IF v_best >= 3          THEN v_ach := v_ach || 'streak_3'::TEXT;         END IF;
  IF v_best >= 7          THEN v_ach := v_ach || 'streak_7'::TEXT;         END IF;
  IF v_goal_days >= 5     THEN v_ach := v_ach || 'goal_crusher'::TEXT;     END IF;
  IF v_complete           THEN v_ach := v_ach || 'profile_complete'::TEXT; END IF;

  RETURN jsonb_build_object(
    'streak_days',             v_current,
    'best_streak',             v_best,
    'active_today',            v_today = ANY (v_days),
    'week_activity',           v_week,
    'today_swipes',            v_today_swipes,
    'daily_goal',              v_goal,
    'goal_days',               v_goal_days,
    'total_swipes',            v_total_swipes,
    'matches',                 v_matches,
    'conversations_started',   v_started,
    'qualified_conversations', v_qualified,
    'messages_sent',           v_messages_sent,
    'profile_complete',        v_complete,
    'xp',                      v_xp,
    'level',                   v_level,
    'level_floor_xp',          50 * (v_level - 1) * (v_level - 1),
    'next_level_xp',           50 * v_level * v_level,
    'achievements',            to_jsonb(v_ach)
  );
END $$;

REVOKE EXECUTE ON FUNCTION public.swipes_server_time()          FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_my_progress(INTEGER)      FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_my_progress(INTEGER)      TO authenticated;
