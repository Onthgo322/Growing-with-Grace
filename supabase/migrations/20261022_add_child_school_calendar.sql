-- Growing With Grace: add a saved school calendar assignment to each child.
-- Run this once in Supabase SQL Editor before using the updated app.
ALTER TABLE public.daycare_children
  ADD COLUMN IF NOT EXISTS school_calendar text;

ALTER TABLE public.daycare_children
  DROP CONSTRAINT IF EXISTS daycare_children_school_calendar_check;

ALTER TABLE public.daycare_children
  ADD CONSTRAINT daycare_children_school_calendar_check
  CHECK (school_calendar IS NULL OR school_calendar IN ('fargo', 'westFargo', 'trinity', 'other'));
