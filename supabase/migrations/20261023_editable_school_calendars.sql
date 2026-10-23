-- Growing With Grace: editable school-year calendars, with per-user data isolation.
-- Run this migration in Supabase SQL Editor before using the Schools tab.
CREATE TABLE IF NOT EXISTS public.daycare_schools (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 name text NOT NULL,
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT daycare_schools_user_name_unique UNIQUE (user_id,name)
);
CREATE TABLE IF NOT EXISTS public.daycare_school_years (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 school_id uuid NOT NULL REFERENCES public.daycare_schools(id) ON DELETE CASCADE,
 school_year text NOT NULL,
 start_year integer NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT daycare_school_years_school_label_unique UNIQUE (school_id,school_year),
 CONSTRAINT daycare_school_years_label_check CHECK (school_year ~ '^[0-9]{4}-[0-9]{4}$' AND start_year BETWEEN 1900 AND 2200)
);
CREATE TABLE IF NOT EXISTS public.daycare_school_months (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 school_year_id uuid NOT NULL REFERENCES public.daycare_school_years(id) ON DELETE CASCADE,
 month_number integer NOT NULL CHECK (month_number BETWEEN 1 AND 12),
 school_days integer NOT NULL DEFAULT 0 CHECK (school_days BETWEEN 0 AND 31),
 non_school_days integer NOT NULL DEFAULT 0 CHECK (non_school_days BETWEEN 0 AND 31),
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT daycare_school_months_year_month_unique UNIQUE (school_year_id,month_number),
 CONSTRAINT daycare_school_months_day_total_check CHECK (school_days + non_school_days <= 31)
);
ALTER TABLE public.daycare_children ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.daycare_schools(id) ON DELETE SET NULL;
ALTER TABLE public.daycare_schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daycare_school_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daycare_school_months ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage their own schools" ON public.daycare_schools;
CREATE POLICY "Users manage their own schools" ON public.daycare_schools FOR ALL USING (auth.uid()=user_id) WITH CHECK (auth.uid()=user_id);
DROP POLICY IF EXISTS "Users manage their own school years" ON public.daycare_school_years;
CREATE POLICY "Users manage their own school years" ON public.daycare_school_years FOR ALL USING (auth.uid()=user_id) WITH CHECK (auth.uid()=user_id);
DROP POLICY IF EXISTS "Users manage their own school months" ON public.daycare_school_months;
CREATE POLICY "Users manage their own school months" ON public.daycare_school_months FOR ALL USING (auth.uid()=user_id) WITH CHECK (auth.uid()=user_id);
INSERT INTO public.daycare_schools (user_id,name)
SELECT DISTINCT c.user_id, seed.name FROM public.daycare_children c
CROSS JOIN (VALUES ('Fargo Public Schools'),('West Fargo Public Schools'),('Trinity'),('Other / no matching calendar')) AS seed(name)
WHERE c.user_id IS NOT NULL ON CONFLICT (user_id,name) DO NOTHING;
UPDATE public.daycare_children c SET school_id=s.id FROM public.daycare_schools s
WHERE c.user_id=s.user_id AND c.school_id IS NULL AND (
 (c.school_calendar='fargo' AND s.name='Fargo Public Schools') OR
 (c.school_calendar='westFargo' AND s.name='West Fargo Public Schools') OR
 (c.school_calendar='trinity' AND s.name='Trinity') OR
 (c.school_calendar='other' AND s.name='Other / no matching calendar'));
CREATE INDEX IF NOT EXISTS daycare_school_years_user_school_idx ON public.daycare_school_years(user_id,school_id,start_year);
CREATE INDEX IF NOT EXISTS daycare_school_months_user_year_idx ON public.daycare_school_months(user_id,school_year_id,month_number);
