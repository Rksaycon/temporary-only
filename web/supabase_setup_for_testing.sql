-- ONE-TIME SETUP to smoke-test the may_laud <-> AI backend integration
-- against Justin's own TRIAGEDelRo Supabase project (pxwhqcvbnoqzzozblctj),
-- instead of waiting on the IS team's project credentials. Run this in
-- THAT project's SQL Editor.
--
-- This creates a citizen_reports table with the exact shape may_laud's
-- code already expects (see app_services.dart submitReport()/
-- checkReportStatus()), plus the AI triage columns from
-- supabase_add_ai_triage_columns.sql. Once the IS team's own project is
-- confirmed, the same schema should already match theirs — only the
-- .env values need to change, not the code.

-- 1. Table
create table if not exists public.citizen_reports (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id),
  category      text,
  subcategory   text,
  description   text,
  location      text,
  photo_urls    text[] default '{}',
  contact       text,
  status        text not null default 'received',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  -- AI triage columns (same as supabase_add_ai_triage_columns.sql)
  severity                     text,
  ai_suggested_severity        text,
  ai_severity_confidence       numeric,
  ai_detected_image_category   text,
  ai_image_valid                boolean,
  requires_manual_review       boolean not null default false
);

-- 2. RLS: residents can insert/read their own reports; any authenticated
--    user can update status (mirrors the IS team's own
--    supabase_admin_policies.sql pattern for this table — permissive for
--    now since there's no admin-role column being enforced yet either).
alter table public.citizen_reports enable row level security;

drop policy if exists "Residents can insert their own reports" on public.citizen_reports;
create policy "Residents can insert their own reports"
  on public.citizen_reports for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Residents can read their own reports" on public.citizen_reports;
create policy "Residents can read their own reports"
  on public.citizen_reports for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Authenticated users can update citizen reports" on public.citizen_reports;
create policy "Authenticated users can update citizen reports"
  on public.citizen_reports for update to authenticated using (true);

-- 3. Storage bucket for report photos (may_laud uploads to 'report-photos').
insert into storage.buckets (id, name, public)
values ('report-photos', 'report-photos', true)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can upload report photos" on storage.objects;
create policy "Authenticated users can upload report photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'report-photos');

drop policy if exists "Anyone can view report photos" on storage.objects;
create policy "Anyone can view report photos"
  on storage.objects for select
  using (bucket_id = 'report-photos');
