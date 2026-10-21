-- Milaud — citizen report history: live status tracking + background push
-- Layered on top of supabase/schema.sql + supabase/admin_schema.sql
-- (citizen_reports, notifications, profiles.fcm_token and the `push` Edge
-- Function's Database Webhook all already exist there).
--
-- WHAT THIS ADDS — the exact same story document requests already have
-- (see document_requests_full_details.sql), for citizen reports:
--
--   web admin updates citizen_reports.status (received/assigned/
--   in_progress/resolved/closed)
--     └─ trigger citizen_reports_notify_status_change      (this file)
--          └─ INSERT INTO public.notifications             (resident's inbox row,
--                                                           type = 'citizen_report')
--               ├─ app open → citizen_reports + notifications realtime channels
--               │             update the report history screen instantly
--               └─ app minimized/closed → Database Webhook (notifications / INSERT)
--                                    → Edge Function `push` → FCM → system tray
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → New query → paste this whole
-- file → Run. Safe to re-run (every statement is drop-if-exists / if-not-exists).
-- Assumes schema.sql (and admin_schema.sql for the web admin's update policy)
-- has already been run.

-- ─────────────────────────────────────────────────────────
-- REALTIME — the mobile history screen matches incoming UPDATE events by row
-- id (CitizenReportsProvider._handleRealtimeChange in content_providers.dart),
-- so UPDATE payloads must carry the full row, not just the changed columns.
-- ─────────────────────────────────────────────────────────
alter table public.citizen_reports replica identity full;

-- Projects created before updated_at existed: add it in place so re-running
-- is safe. The history screen surfaces "Last Updated" from this.
alter table public.citizen_reports
  add column if not exists updated_at timestamptz not null default now();

-- Keep updated_at accurate whenever an admin changes the status from the web
-- dashboard (same helper document_requests already uses).
drop trigger if exists citizen_reports_set_updated_at
  on public.citizen_reports;
create trigger citizen_reports_set_updated_at
  before update on public.citizen_reports
  for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────
-- AUTO-NOTIFY the resident on a status change -----------------------------
-- The inserted row is what the app's `notifications` realtime subscription
-- picks up (live in-app inbox entry) AND what the Database Webhook turns into
-- an FCM push via the `push` Edge Function — reaching the phone even while
-- the app is backgrounded or closed. SECURITY DEFINER so the trigger can
-- insert into the resident's inbox regardless of the admin's session.
-- ─────────────────────────────────────────────────────────
create or replace function public.citizen_reports_status_label(status text)
returns text
language sql
immutable
set search_path = public
as $$
  -- Friendly resident-facing wording per status. The web admin may store the
  -- raw value in any case; unknown values fall back to initcap() so the
  -- message never reads blank.
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
-- REALTIME — expose citizen_reports via Postgres Changes. The resident
-- history screen (content_providers.dart: CitizenReportsProvider) listens on
-- it; without the table in the supabase_realtime publication an admin's edit
-- never reaches the phone and the list only refreshes on a manual pull.
-- `notifications` was added by schema.sql — repeated here (guarded) so this
-- file stands alone.
-- ─────────────────────────────────────────────────────────
do $$
declare
  t text;
begin
  foreach t in array array['citizen_reports', 'notifications'] loop
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
