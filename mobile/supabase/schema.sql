-- Milaud app — full schema for the "Mylaud:)" Supabase project
-- (enojnhijfabncaeoyctt). Generated from what the Flutter app actually
-- reads/writes (see lib/services/app_services.dart,
-- lib/providers/content_providers.dart, lib/providers/auth_provider.dart,
-- lib/services/push_notification_service.dart).
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → New query → paste this
-- whole file → Run. This project was created empty, so there's no
-- cleanup step — every statement here is IF NOT EXISTS / OR REPLACE, so
-- it's safe to re-run.

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────
-- PROFILES — one row per auth user (auth_provider.dart)
-- ─────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  name       text not null default '',
  email      text not null default '',
  phone      text,
  address    text,
  avatar_url text,
  fcm_token  text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view their own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ─────────────────────────────────────────────────────────
-- ANNOUNCEMENTS (content_providers.dart, app_services.dart)
-- ─────────────────────────────────────────────────────────
create table if not exists public.announcements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text not null,
  category     text not null default 'General',
  image_url    text,
  is_important boolean not null default false,
  created_by   uuid references auth.users (id),
  created_at   timestamptz not null default now()
);

alter table public.announcements enable row level security;

create policy "Anyone can view announcements"
  on public.announcements for select
  using (true);

-- NOTE: this lets any signed-in resident post an announcement, because
-- this app has no admin-role concept yet. Once you add one (e.g. a
-- `role` column on profiles), tighten this to something like
-- `exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')`.
create policy "Authenticated users can post announcements"
  on public.announcements for insert
  with check (auth.role() = 'authenticated');

-- Per-user read state for announcements (kept separate from the
-- announcement itself since read status is per-resident, not global).
create table if not exists public.announcement_reads (
  user_id         uuid not null references auth.users (id) on delete cascade,
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (user_id, announcement_id)
);

alter table public.announcement_reads enable row level security;

create policy "Users can view their own read receipts"
  on public.announcement_reads for select
  using (auth.uid() = user_id);

create policy "Users can mark announcements as read for themselves"
  on public.announcement_reads for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own read receipts"
  on public.announcement_reads for update
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- NOTIFICATIONS (content_providers.dart, app_services.dart,
-- push_notification_service.dart)
-- ─────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  title      text not null,
  message    text not null,
  type       text not null default 'system',
  is_read    boolean not null default false,
  data       jsonb,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Users can view their own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Users can create their own notifications"
  on public.notifications for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own notifications"
  on public.notifications for update
  using (auth.uid() = user_id);

create policy "Users can delete their own notifications"
  on public.notifications for delete
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- HOTLINES — public read-only reference data (app_services.dart)
-- ─────────────────────────────────────────────────────────
create table if not exists public.hotlines (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  number      text not null,
  type        text not null default 'General',
  description text,
  icon        text,
  is_active   boolean not null default true
);

alter table public.hotlines enable row level security;

create policy "Anyone can view active hotlines"
  on public.hotlines for select
  using (true);

-- ─────────────────────────────────────────────────────────
-- DOCUMENT REQUESTS (content_providers.dart, app_services.dart)
-- ─────────────────────────────────────────────────────────
create table if not exists public.document_requests (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  document_type    text not null,
  purpose          text not null,
  status           text not null default 'pending',
  fee              text,
  notes            text,
  -- Everything the resident fills in on the mobile request form, so the web
  -- admin can show it. `notes` is kept (it still carries the urgency string)
  -- for admins that already render that column.
  full_name        text,
  address          text,
  urgency          text,
  additional_notes text,
  attachment_urls  text[] not null default '{}',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

alter table public.document_requests replica identity full;
alter table public.notifications replica identity full;

-- Projects created before updated_at existed: add it in place so re-running
-- this file is safe. The resident tracker surfaces "Last Updated" from this.
alter table public.document_requests
  add column if not exists updated_at timestamptz not null default now();

-- Detail columns added with the "show the resident's full request in the web
-- admin" change — same guard so an already-provisioned project picks them up
-- without a rebuild.
alter table public.document_requests
  add column if not exists full_name        text;
alter table public.document_requests
  add column if not exists address          text;
alter table public.document_requests
  add column if not exists urgency          text;
alter table public.document_requests
  add column if not exists additional_notes text;
alter table public.document_requests
  add column if not exists attachment_urls  text[] not null default '{}';

alter table public.document_requests enable row level security;

create policy "Users can view their own document requests"
  on public.document_requests for select
  using (auth.uid() = user_id);

create policy "Users can create their own document requests"
  on public.document_requests for insert
  with check (auth.uid() = user_id);

-- Auto-touch updated_at -----------------------------------------------------
-- The resident tracker shows "Last Updated", so keep it accurate whenever an
-- admin changes a request's status from the web dashboard.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists document_requests_set_updated_at
  on public.document_requests;
create trigger document_requests_set_updated_at
  before update on public.document_requests
  for each row execute function public.set_updated_at();

-- Auto-notify the resident on a status change -------------------------------
-- When an admin moves a request to processing / ready / released / rejected,
-- drop a notification into that resident's inbox. That row is what the app's
-- `notifications` realtime subscription picks up (live in-app update) AND what
-- the Database Webhook -> `push` Edge Function turns into an FCM push that
-- reaches the phone even while the app is backgrounded or closed.
--
-- SECURITY DEFINER so the insert can target the *resident's* user_id without
-- tripping the "Users can create their own notifications" RLS policy.
--
-- See supabase/document_requests_full_details.sql and
-- supabase/PUSH_NOTIFICATIONS_SETUP.md.
create or replace function public.notify_document_request_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  status_label text;
  doc_label    text;
  ref_label    text;
begin
  -- Only an actual status change should buzz the resident's phone.
  if new.status is not distinct from old.status then
    return new;
  end if;

  status_label := case lower(coalesce(new.status, ''))
    when 'pending'    then 'Pending Review'
    when 'processing' then 'Processing'
    when 'ready'      then 'Ready for Pickup'
    when 'released'   then 'Released'
    when 'completed'  then 'Completed'
    when 'rejected'   then 'Rejected'
    else initcap(coalesce(new.status, 'updated'))
  end;

  doc_label := coalesce(nullif(new.document_type, ''), 'Document');
  -- Matches DocumentRequest.reference in content_providers.dart.
  ref_label := 'MLR-' || upper(substr(replace(new.id::text, '-', ''), 1, 8));

  insert into public.notifications (user_id, title, message, type, data)
  values (
    new.user_id,
    'Document request update',
    'Your ' || doc_label || ' request (' || ref_label || ') is now '
      || status_label || '.',
    'document_request',
    jsonb_build_object(
      'type',                'document_request',
      'document_request_id', new.id,
      'status',              new.status,
      'reference',           ref_label
    )
  );

  return new;
end $$;

drop trigger if exists document_requests_notify_status_change
  on public.document_requests;
create trigger document_requests_notify_status_change
  after update on public.document_requests
  for each row execute function public.notify_document_request_status_change();

-- ─────────────────────────────────────────────────────────
-- CITIZEN REPORTS (app_services.dart, ai_triage_service.dart results)
-- ─────────────────────────────────────────────────────────
create table if not exists public.citizen_reports (
  id                           uuid primary key default gen_random_uuid(),
  user_id                      uuid not null references auth.users (id) on delete cascade,
  category                     text not null,
  subcategory                  text not null,
  description                  text not null,
  location                     text not null,
  photo_urls                   text[] not null default '{}',
  contact                      text,
  severity                     text,
  ai_suggested_severity        text,
  ai_severity_confidence       numeric,
  ai_detected_image_category   text,
  ai_image_valid               boolean,
  requires_manual_review       boolean not null default false,
  status                       text not null default 'received',
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now()
);

alter table public.citizen_reports enable row level security;

create policy "Users can view their own citizen reports"
  on public.citizen_reports for select
  using (auth.uid() = user_id);

create policy "Users can create their own citizen reports"
  on public.citizen_reports for insert
  with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- CITIZEN REPORT status-change plumbing (mirrors document_requests above;
-- the standalone supabase/citizen_reports_status_tracking.sql installs the
-- exact same pieces for projects provisioned before that file existed).
--
-- * updated_at — the history screen's "Last Updated" row; bumped whenever the
--   web admin changes the status.
-- * REPLICA IDENTITY FULL — the mobile history screen matches realtime UPDATE
--   events by row id (CitizenReportsProvider._handleRealtimeChange), so the
--   payload must carry the full row, not just the changed column.
-- * notify_status_change — inserts the resident's inbox row (type
--   'citizen_report'), which BOTH the app's realtime subscription shows live
--   AND the Database Webhook -> `push` Edge Function turns into an FCM push
--   that reaches the phone while the app is backgrounded or closed.
-- ─────────────────────────────────────────────────────────
alter table public.citizen_reports
  add column if not exists updated_at timestamptz not null default now();

alter table public.citizen_reports replica identity full;

drop trigger if exists citizen_reports_set_updated_at
  on public.citizen_reports;
create trigger citizen_reports_set_updated_at
  before update on public.citizen_reports
  for each row execute function public.set_updated_at();

-- Friendly resident-facing wording per status (used by the trigger below).
create or replace function public.citizen_reports_status_label(status text)
returns text
language sql
immutable
set search_path = public
as $$
  select case lower(coalesce(status, ''))
    when 'received'    then 'Received'
    when 'assigned'    then 'Assigned'
    when 'in_progress' then 'Ongoing'
    when 'resolved'    then 'Resolved'
    when 'closed'      then 'Closed'
    else initcap(coalesce(status, 'received'))
  end;
$$;

create or replace function public.citizen_reports_notify_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ref_label text;
  old_label text;
  new_label text;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  -- Matches CitizenReport.reference in content_providers.dart so the push,
  -- the in-app notification and the history card all show the same code.
  ref_label := 'RPT-' || upper(substr(replace(new.id::text, '-', ''), 1, 8));
  old_label  := public.citizen_reports_status_label(old.status);
  new_label  := public.citizen_reports_status_label(new.status);

  insert into public.notifications (user_id, title, message, type, data)
  values (
    new.user_id,
    'Report update — ' || new_label,
    'Your report ' || ref_label || ' moved from ' || old_label
      || ' to ' || new_label || '.',
    'citizen_report',
    jsonb_build_object(
      'type',       'citizen_report',
      'report_id',  new.id::text,
      'status',     new.status,
      'reference',  ref_label
    )
  );

  return new;
end;
$$;

drop trigger if exists citizen_reports_notify_status_change
  on public.citizen_reports;
create trigger citizen_reports_notify_status_change
  after update of status on public.citizen_reports
  for each row
  when (old.status is distinct from new.status)
  execute function public.citizen_reports_notify_status_change();

-- ─────────────────────────────────────────────────────────
-- FLOOD ALERTS — public read-only (app_services.dart)
-- ─────────────────────────────────────────────────────────
create table if not exists public.flood_alerts (
  id             uuid primary key default gen_random_uuid(),
  level          text not null default 'Low',
  affected_areas text[] not null default '{}',
  water_level    text,
  advice         text,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.flood_alerts enable row level security;

create policy "Anyone can view flood alerts"
  on public.flood_alerts for select
  using (true);

-- ─────────────────────────────────────────────────────────
-- DASHBOARD STATS SOURCE TABLES — public read-only
-- (content_providers.dart: DashboardStatsNotifier)
-- ─────────────────────────────────────────────────────────
create table if not exists public.projects (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default '',
  description text,
  status      text not null default 'active', -- 'active' counts toward the dashboard
  created_at  timestamptz not null default now()
);

alter table public.projects enable row level security;

create policy "Anyone can view projects"
  on public.projects for select
  using (true);

create table if not exists public.municipal_budget (
  fiscal_year     int primary key,
  total_allocated numeric not null default 0,
  total_utilized  numeric not null default 0
);

alter table public.municipal_budget enable row level security;

create policy "Anyone can view the municipal budget"
  on public.municipal_budget for select
  using (true);

create table if not exists public.barangay_assemblies (
  id       uuid primary key default gen_random_uuid(),
  title    text not null default '',
  held_at  timestamptz not null default now()
);

alter table public.barangay_assemblies enable row level security;

create policy "Anyone can view barangay assemblies"
  on public.barangay_assemblies for select
  using (true);

-- ─────────────────────────────────────────────────────────
-- STORAGE — report-photos bucket (app_services.dart:
-- CitizenReportService.submitReport() uploads here)
-- ─────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('report-photos', 'report-photos', true)
on conflict (id) do nothing;

-- storage.objects is a shared system table, so re-running this script
-- would otherwise hit "policy already exists" on a second run — drop
-- first so this block stays safe to re-run.
drop policy if exists "Anyone can view report photos" on storage.objects;
drop policy if exists "Users can upload their own report photos" on storage.objects;

create policy "Anyone can view report photos"
  on storage.objects for select
  using (bucket_id = 'report-photos');

-- Upload path is '<uid>/<timestamp>_<n>.jpg' — this restricts uploads to
-- each resident's own folder (see submitReport() in app_services.dart).
create policy "Users can upload their own report photos"
  on storage.objects for insert
  with check (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- document-attachments bucket — supporting documents the resident attaches to
-- a document request (content_providers.dart: submitRequest()).
insert into storage.buckets (id, name, public)
values ('document-attachments', 'document-attachments', true)
on conflict (id) do nothing;

drop policy if exists "Anyone can view document attachments" on storage.objects;
drop policy if exists "Users can upload their own document attachments" on storage.objects;

create policy "Anyone can view document attachments"
  on storage.objects for select
  using (bucket_id = 'document-attachments');

create policy "Users can upload their own document attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'document-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─────────────────────────────────────────────────────────
-- SEED DATA — optional, so screens aren't empty on first run.
-- Delete or edit freely; the app works fine with none of this.
-- ─────────────────────────────────────────────────────────
insert into public.hotlines (name, number, type, is_active) values
  ('BFP Milaor',  '0920-983-9802', 'Fire',   true),
  ('PNP Milaor',  '0917-000-0000', 'Police', true),
  ('MDRRMO',      '0918-000-0000', 'Rescue', true)
on conflict do nothing;

-- REALTIME ------------------------------------------------------------------
-- Expose the tables the app subscribes to via Postgres Changes. The resident
-- document tracker (content_providers.dart: DocumentRequestsProvider) listens
-- for live updates on `document_requests`; notifications already had a
-- client-side subscription too. Both are added to the supabase_realtime
-- publication here so updates actually stream to the app. Guarded so
-- re-running this file is safe.
do $$
declare
  t text;
begin
  foreach t in array array['document_requests', 'notifications', 'citizen_reports'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t
      );
    end if;
  end loop;
end $$;
