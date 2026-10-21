-- Stores EVERYTHING the resident fills in on the mobile "Document Request"
-- form so the IS team's React admin (Maylaud_Web) can show it, and pushes an
-- automatic notification to the resident whenever an admin changes a
-- request's status.
--
-- Before this file, DocumentRequestScreen collected four things that never
-- reached the database at all:
--   * Full Name            -> dropped
--   * Complete Address     -> dropped
--   * Additional Notes     -> dropped
--   * Attachments (photos) -> dropped (files were picked, then discarded)
-- ...and "urgency" was smuggled into the `notes` column as the string
-- 'Urgency: Normal (3-5 days)'. This adds real columns for all of it.
-- `notes` is still written with the same urgency string so any existing admin
-- screen that renders `notes` keeps working unchanged.
--
-- It also installs an AFTER UPDATE trigger that writes a row into
-- `public.notifications` when `status` changes. That single insert is what
-- drives BOTH halves of the live-update story:
--   1. the mobile app's `notifications` realtime subscription shows the
--      notification instantly while the app is open, and
--   2. the Database Webhook -> `push` Edge Function -> FCM push wakes the
--      phone even when the app is backgrounded or closed.
--
-- HOW TO RUN: Supabase Dashboard -> SQL Editor -> New query -> paste this
-- whole file -> Run. Safe to re-run.
--
-- THEN (for the background push — see supabase/PUSH_NOTIFICATIONS_SETUP.md):
--   1. deploy the `push` Edge Function in supabase/functions/push/,
--   2. create a Database Webhook on public.notifications / INSERT.

-- ─────────────────────────────────────────────────────────
-- DOCUMENT REQUESTS — new detail columns
-- ─────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────
-- STORAGE — document-attachments bucket
-- (DocumentRequestsProvider.submitRequest() uploads here)
-- ─────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('document-attachments', 'document-attachments', true)
on conflict (id) do nothing;

-- storage.objects is a shared system table, so re-running this script would
-- otherwise hit "policy already exists" — drop first so it stays safe.
drop policy if exists "Anyone can view document attachments" on storage.objects;
drop policy if exists "Users can upload their own document attachments" on storage.objects;

create policy "Anyone can view document attachments"
  on storage.objects for select
  using (bucket_id = 'document-attachments');

-- Upload path is '<uid>/<timestamp>_<n>.jpg' — restricts uploads to each
-- resident's own folder (see submitRequest() in content_providers.dart).
create policy "Users can upload their own document attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'document-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─────────────────────────────────────────────────────────
-- NOTIFY ON STATUS CHANGE
-- Fires when an admin flips a request's status from the web dashboard
-- (pending -> processing -> ready -> released, or -> rejected) and drops a
-- notification into the resident's inbox.
--
-- SECURITY DEFINER + `set search_path = public`: the trigger must insert a row
-- whose `user_id` is the *resident*, not the admin who made the change — that
-- would otherwise be blocked by the "Users can create their own notifications"
-- RLS policy (auth.uid() = user_id). Running as the function owner bypasses
-- RLS for this one internal write only; the app itself still can't write to
-- another user's notifications.
--
-- The `reference` (MLR-XXXXXXXX) is derived from the row id exactly the way
-- DocumentRequest.reference does it in content_providers.dart, so the push and
-- the in-app tracker always show the same code.
-- ─────────────────────────────────────────────────────────
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
  -- Only fire on an actual status change — a notes/address edit shouldn't
  -- buzz the resident's phone.
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
-- REALTIME — make sure these tables are actually streamed.
-- (schema.sql already does this; repeated here so this file stands alone.)
-- The resident tracker listens for Postgres Changes on `document_requests`;
-- without the table in the supabase_realtime publication an admin's edit never
-- reaches the phone and the tracking screen only refreshes on a manual
-- pull-to-refresh. `notifications` powers the live in-app inbox.
--
-- REPLICA IDENTITY FULL is required for UPDATE/DELETE payloads to include the
-- full row. The mobile tracker matches incoming realtime events by row id
-- (see _handleRealtimeChange in content_providers.dart) — without it, the
-- realtime payload carries only the changed `status` and the app's event
-- handler can't merge it into the card, so no live update appears.
-- ─────────────────────────────────────────────────────────
alter table public.document_requests replica identity full;
alter table public.notifications replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'document_requests'
  ) then
    alter publication supabase_realtime add table public.document_requests;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

