-- =============================================================================
-- GitAlong — 0004 product metrics (backend/admin only)
-- =============================================================================
-- North-star metric: *qualified conversations* — matches where both people
-- have written and the thread has at least 6 messages. A match nobody talks in
-- is not a collaboration; this is the number to grow.
-- Read through GET /api/v1/admin/metrics (service role). Never exposed to clients.
-- =============================================================================

DROP VIEW IF EXISTS public.admin_daily_metrics;
CREATE VIEW public.admin_daily_metrics AS
WITH days AS (
  SELECT generate_series(
           date_trunc('day', now()) - INTERVAL '29 days',
           date_trunc('day', now()),
           INTERVAL '1 day'
         ) AS day
),
thread_stats AS (
  SELECT match_id,
         count(*)                   AS messages,
         count(DISTINCT sender_id)  AS participants
    FROM public.messages
   GROUP BY match_id
)
SELECT
  d.day::DATE AS day,
  (SELECT count(*) FROM public.users u
    WHERE u.created_at >= d.day AND u.created_at < d.day + INTERVAL '1 day')             AS signups,
  (SELECT count(DISTINCT s.swiper_id) FROM public.swipes s
    WHERE s.swiped_at >= d.day AND s.swiped_at < d.day + INTERVAL '1 day')               AS active_swipers,
  (SELECT count(*) FROM public.swipes s
    WHERE s.swiped_at >= d.day AND s.swiped_at < d.day + INTERVAL '1 day')               AS swipes,
  (SELECT count(*) FROM public.swipes s
    WHERE s.swiped_at >= d.day AND s.swiped_at < d.day + INTERVAL '1 day'
      AND s.action IN ('like', 'superLike'))                                             AS likes,
  (SELECT count(*) FROM public.matches m
    WHERE m.matched_at >= d.day AND m.matched_at < d.day + INTERVAL '1 day')             AS matches,
  (SELECT count(*) FROM public.messages x
    WHERE x.sent_at >= d.day AND x.sent_at < d.day + INTERVAL '1 day')                   AS messages,
  (SELECT count(*) FROM public.matches m JOIN thread_stats t ON t.match_id = m.id
    WHERE m.matched_at >= d.day AND m.matched_at < d.day + INTERVAL '1 day'
      AND t.participants = 2 AND t.messages >= 6)                                        AS qualified_conversations
FROM days d
ORDER BY d.day DESC;

REVOKE ALL ON public.admin_daily_metrics FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_daily_metrics TO service_role;
