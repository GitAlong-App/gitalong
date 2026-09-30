-- =============================================================
-- GitAlong Supabase Schema (snake_case columns - Postgres standard)
-- Run this in Supabase SQL Editor
-- If you already ran the old schema, run supabase_migration.sql instead
-- =============================================================

-- Create Users table
CREATE TABLE IF NOT EXISTS public.users (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
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
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  last_active_at TIMESTAMP WITH TIME ZONE
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users only" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Enable update for users based on id" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Enable delete for users based on id" ON public.users FOR DELETE USING (auth.uid() = id);

-- Create Swipes table
CREATE TABLE IF NOT EXISTS public.swipes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  swiper_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  swiped_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  swiped_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_swipe UNIQUE (swiper_id, swiped_user_id)
);

ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable insert for authenticated users" ON public.swipes FOR INSERT WITH CHECK (auth.uid() = swiper_id);
CREATE POLICY "Enable read for own and received swipes" ON public.swipes FOR SELECT USING (auth.uid() = swiper_id OR auth.uid() = swiped_user_id);
CREATE POLICY "Enable delete for own swipes" ON public.swipes FOR DELETE USING (auth.uid() = swiper_id);


-- Create Matches table
CREATE TABLE IF NOT EXISTS public.matches (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  users UUID[] NOT NULL,
  matched_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  last_message TEXT,
  last_message_at TIMESTAMP WITH TIME ZONE,
  is_read BOOLEAN DEFAULT false
);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can see their matches" ON public.matches FOR SELECT USING (auth.uid() = ANY(users));
CREATE POLICY "Users can create matches" ON public.matches FOR INSERT WITH CHECK (auth.uid() = ANY(users));
CREATE POLICY "Users can update their matches" ON public.matches FOR UPDATE USING (auth.uid() = ANY(users));
CREATE POLICY "Users can delete their matches" ON public.matches FOR DELETE USING (auth.uid() = ANY(users));

-- Create Messages table
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'text',
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  is_read BOOLEAN DEFAULT false
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view messages in their matches" ON public.messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Users can insert their own messages" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Users can update their messages" ON public.messages FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Users can delete their messages" ON public.messages FOR DELETE USING (auth.uid() = sender_id);

-- Create GitHub Cache table
CREATE TABLE IF NOT EXISTS public.github_cache (
  id UUID REFERENCES public.users(id) PRIMARY KEY,
  username TEXT NOT NULL,
  total_stars INTEGER DEFAULT 0,
  total_forks INTEGER DEFAULT 0,
  total_commits INTEGER DEFAULT 0,
  public_repos INTEGER DEFAULT 0,
  language_count INTEGER DEFAULT 0,
  languages TEXT[] DEFAULT '{}',
  topics TEXT[] DEFAULT '{}',
  activity_score NUMERIC DEFAULT 0,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.github_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.github_cache FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON public.github_cache FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Enable update for auth users" ON public.github_cache FOR UPDATE USING (auth.uid() = id);

-- Realtime enablement
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.matches;
