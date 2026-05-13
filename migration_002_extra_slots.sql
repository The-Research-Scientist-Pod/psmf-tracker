-- ============================================================================
-- PSMF Tracker — Migration 002: variable-length day slots
-- ============================================================================
-- Run this in your Supabase SQL Editor after the initial schema.sql.
-- It is safe to re-run; every statement is idempotent.
--
-- Adds two capabilities:
--   1. day_logs.slot_index can now go up to 19 (was 0-4 only)
--   2. user_state remembers how many slots each day currently has,
--      so empty extra slots persist across reloads
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. RELAX THE SLOT INDEX CHECK CONSTRAINT
-- ---------------------------------------------------------------------------
-- The original constraint was BETWEEN 0 AND 4. We replace it with BETWEEN
-- 0 AND 19, which gives plenty of room for extra slots without allowing
-- garbage values (e.g. someone accidentally inserting slot_index = 999).
-- ---------------------------------------------------------------------------
ALTER TABLE public.day_logs
  DROP CONSTRAINT IF EXISTS day_logs_slot_index_check;

ALTER TABLE public.day_logs
  ADD CONSTRAINT day_logs_slot_index_check
  CHECK (slot_index BETWEEN 0 AND 19);


-- ---------------------------------------------------------------------------
-- 2. ADD SLOT COUNT COLUMNS TO USER_STATE
-- ---------------------------------------------------------------------------
-- These let the app remember "this user has 6 slots on Thursdays" even
-- when one or more of those slots is empty (and therefore not represented
-- by any row in day_logs).
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_state
  ADD COLUMN IF NOT EXISTS thursday_slots INT DEFAULT 5;

ALTER TABLE public.user_state
  ADD COLUMN IF NOT EXISTS sunday_slots INT DEFAULT 5;


-- ---------------------------------------------------------------------------
-- Done. Verify by inspecting the updated tables:
--   SELECT column_name, data_type, column_default
--     FROM information_schema.columns
--    WHERE table_name = 'user_state';
-- ---------------------------------------------------------------------------
