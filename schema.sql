-- ============================================================================
-- PSMF Tracker — Supabase schema migration
-- ============================================================================
-- Run this script once in your Supabase project's SQL Editor.
-- It creates three tables, one trigger, and the Row Level Security policies
-- that prevent users from seeing each other's data.
--
-- The data model:
--   meals       — user-built custom meals (default meals stay in client JS)
--   day_logs    — which meal is in which slot for Thursday / Sunday
--   user_state  — top-level per-user state (streak counter, fish oil toggle)
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. CUSTOM MEALS
-- ---------------------------------------------------------------------------
-- Each row represents one meal the user has built via the in-app builder.
-- Default meals (the seed library "Yogurt + whey bowl", "Cod + steamed veg",
-- etc.) live in the client-side JavaScript and never touch this table.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.meals (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  category    TEXT NOT NULL CHECK (category IN ('breakfast', 'lunch', 'snack', 'dinner', 'prebed')),
  kcal        NUMERIC NOT NULL CHECK (kcal >= 0),
  protein     NUMERIC NOT NULL CHECK (protein >= 0),
  fat         NUMERIC NOT NULL CHECK (fat >= 0),
  carbs       NUMERIC NOT NULL CHECK (carbs >= 0),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Index makes "all meals for user X" queries fast even at large scale.
CREATE INDEX IF NOT EXISTS meals_user_id_idx ON public.meals(user_id);


-- ---------------------------------------------------------------------------
-- 2. DAY LOGS
-- ---------------------------------------------------------------------------
-- One row per OCCUPIED slot. When a slot is empty there is simply no row.
-- meal_id is TEXT (not UUID) on purpose: it can hold either a UUID string
-- for a custom meal, OR a hard-coded identifier like 'plan-a-1' for a
-- default meal from the seed library. The application resolves these at
-- render time by looking in both pools.
--
-- The composite primary key (user_id, day_key, slot_index) guarantees that
-- a single slot can hold at most one meal — upserts will overwrite cleanly.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.day_logs (
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day_key     TEXT NOT NULL CHECK (day_key IN ('thursday', 'sunday')),
  slot_index  INT NOT NULL CHECK (slot_index BETWEEN 0 AND 4),
  meal_id     TEXT NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, day_key, slot_index)
);


-- ---------------------------------------------------------------------------
-- 3. USER STATE
-- ---------------------------------------------------------------------------
-- One row per user, auto-created on signup by the trigger below.
-- Holds simple top-level state that doesn't deserve its own table.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_state (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  streak      INT DEFAULT 0,
  fishoil     BOOLEAN DEFAULT FALSE,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ---------------------------------------------------------------------------
-- 4. AUTO-CREATE USER STATE ON SIGNUP
-- ---------------------------------------------------------------------------
-- When Supabase Auth creates a new user, this trigger ensures they get
-- a corresponding row in user_state immediately, so the application never
-- has to do an "is there a row?" check before reading.
--
-- SECURITY DEFINER means the function runs with elevated privileges
-- (necessary to write to public.user_state from a trigger on auth.users).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_state (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Drop and recreate the trigger so this script is idempotent.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();


-- ---------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------------
-- This is THE security boundary. The anon key in your public JavaScript
-- is meaningless without these policies — they ensure that every query,
-- regardless of how it's crafted, can only touch rows belonging to the
-- currently authenticated user.
--
-- auth.uid() is a built-in function that returns the user ID of the
-- session making the request, or NULL if the request is unauthenticated.
-- ---------------------------------------------------------------------------
ALTER TABLE public.meals      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.day_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_state ENABLE ROW LEVEL SECURITY;

-- meals: full CRUD restricted to the row owner
DROP POLICY IF EXISTS meals_owner_policy ON public.meals;
CREATE POLICY meals_owner_policy ON public.meals
  FOR ALL
  TO authenticated
  USING       (auth.uid() = user_id)
  WITH CHECK  (auth.uid() = user_id);

-- day_logs: full CRUD restricted to the row owner
DROP POLICY IF EXISTS day_logs_owner_policy ON public.day_logs;
CREATE POLICY day_logs_owner_policy ON public.day_logs
  FOR ALL
  TO authenticated
  USING       (auth.uid() = user_id)
  WITH CHECK  (auth.uid() = user_id);

-- user_state: full CRUD restricted to the row owner
DROP POLICY IF EXISTS user_state_owner_policy ON public.user_state;
CREATE POLICY user_state_owner_policy ON public.user_state
  FOR ALL
  TO authenticated
  USING       (auth.uid() = user_id)
  WITH CHECK  (auth.uid() = user_id);


-- ---------------------------------------------------------------------------
-- Done. Verify by signing up a test user via the app and running:
--   SELECT * FROM auth.users;       -- should show your account
--   SELECT * FROM public.user_state; -- should show one row (auto-created)
-- ---------------------------------------------------------------------------
