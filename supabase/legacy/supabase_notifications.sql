-- =============================================================
-- GitAlong Notifications Table
-- =============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read_at ON public.notifications(user_id, read_at);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can only read and update their own notifications
CREATE POLICY "Users can read own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications (e.g. mark read)"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Enable Realtime
alter publication supabase_realtime add table public.notifications;
