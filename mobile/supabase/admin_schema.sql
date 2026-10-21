-- Admin access for the IS team's React admin/official web app — layered
-- on top of supabase/schema.sql. Adds a `role` column to profiles and an
-- admin carve-out to every policy an admin dashboard needs, WITHOUT
-- touching the existing resident-only policies (the Flutter app's
-- current behavior keeps working unchanged).
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → New query → paste this
-- whole file → Run. Safe to re-run.

-- ─────────────────────────────────────────────────────────
-- ROLE COLUMN
-- ─────────────────────────────────────────────────────────
alter table public.profiles add column if not exists role text not null default 'resident';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_role_check'
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('resident', 'admin'));
  end if;
end $$;

-- ─────────────────────────────────────────────────────────
-- is_admin() — SECURITY DEFINER so the role lookup bypasses RLS
-- entirely. Without this, a policy on `profiles` that queries
-- `profiles` to check the caller's own role can be fragile/recursive;
-- this is the standard, safe pattern for an admin-role check.
-- ─────────────────────────────────────────────────────────
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ─────────────────────────────────────────────────────────
-- PROFILES — admins can see/update every resident's profile
-- (e.g. to look someone up, or promote another admin)
-- ─────────────────────────────────────────────────────────
drop policy if exists "Admins can view all profiles" on public.profiles;
create policy "Admins can view all profiles"
  on public.profiles for select
  using (public.is_admin());

drop policy if exists "Admins can update any profile" on public.profiles;
create policy "Admins can update any profile"
  on public.profiles for update
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- CITIZEN REPORTS — admins can view all + update status
-- (there was previously no update policy for this table at all —
-- not even for the report's own owner)
-- ─────────────────────────────────────────────────────────
drop policy if exists "Admins can view all citizen reports" on public.citizen_reports;
create policy "Admins can view all citizen reports"
  on public.citizen_reports for select
  using (public.is_admin());

drop policy if exists "Admins can update citizen reports" on public.citizen_reports;
create policy "Admins can update citizen reports"
  on public.citizen_reports for update
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- DOCUMENT REQUESTS — admins can view all + update status
-- ─────────────────────────────────────────────────────────
drop policy if exists "Admins can view all document requests" on public.document_requests;
create policy "Admins can view all document requests"
  on public.document_requests for select
  using (public.is_admin());

drop policy if exists "Admins can update document requests" on public.document_requests;
create policy "Admins can update document requests"
  on public.document_requests for update
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- ANNOUNCEMENTS — FIX: previously ANY authenticated resident could
-- post one (see schema.sql's own note about this). Now only admins can
-- post/edit/delete; everyone can still read, unchanged.
-- ─────────────────────────────────────────────────────────
drop policy if exists "Authenticated users can post announcements" on public.announcements;
drop policy if exists "Admins can post announcements" on public.announcements;
create policy "Admins can post announcements"
  on public.announcements for insert
  with check (public.is_admin());

drop policy if exists "Admins can update announcements" on public.announcements;
create policy "Admins can update announcements"
  on public.announcements for update
  using (public.is_admin());

drop policy if exists "Admins can delete announcements" on public.announcements;
create policy "Admins can delete announcements"
  on public.announcements for delete
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- HOTLINES — previously read-only for everyone, no one could manage
-- them at all
-- ─────────────────────────────────────────────────────────
drop policy if exists "Admins can insert hotlines" on public.hotlines;
create policy "Admins can insert hotlines"
  on public.hotlines for insert
  with check (public.is_admin());

drop policy if exists "Admins can update hotlines" on public.hotlines;
create policy "Admins can update hotlines"
  on public.hotlines for update
  using (public.is_admin());

drop policy if exists "Admins can delete hotlines" on public.hotlines;
create policy "Admins can delete hotlines"
  on public.hotlines for delete
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- FLOOD ALERTS — same gap: read-only for everyone before this
-- ─────────────────────────────────────────────────────────
drop policy if exists "Admins can insert flood alerts" on public.flood_alerts;
create policy "Admins can insert flood alerts"
  on public.flood_alerts for insert
  with check (public.is_admin());

drop policy if exists "Admins can update flood alerts" on public.flood_alerts;
create policy "Admins can update flood alerts"
  on public.flood_alerts for update
  using (public.is_admin());

drop policy if exists "Admins can delete flood alerts" on public.flood_alerts;
create policy "Admins can delete flood alerts"
  on public.flood_alerts for delete
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- NOTIFICATIONS — admins can send a notification to any resident
-- (the existing insert policy only allows auth.uid() = user_id, i.e.
-- sending to yourself — needed so e.g. "your report was resolved" can
-- actually be sent to the resident, not just self-notifications)
-- ─────────────────────────────────────────────────────────
drop policy if exists "Admins can create notifications for anyone" on public.notifications;
create policy "Admins can create notifications for anyone"
  on public.notifications for insert
  with check (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- PROJECTS / MUNICIPAL BUDGET / BARANGAY ASSEMBLIES — dashboard stat
-- source tables, previously read-only for everyone with no way to
-- manage them at all
-- ─────────────────────────────────────────────────────────
drop policy if exists "Admins can insert projects" on public.projects;
create policy "Admins can insert projects"
  on public.projects for insert
  with check (public.is_admin());
drop policy if exists "Admins can update projects" on public.projects;
create policy "Admins can update projects"
  on public.projects for update
  using (public.is_admin());
drop policy if exists "Admins can delete projects" on public.projects;
create policy "Admins can delete projects"
  on public.projects for delete
  using (public.is_admin());

drop policy if exists "Admins can insert municipal budget" on public.municipal_budget;
create policy "Admins can insert municipal budget"
  on public.municipal_budget for insert
  with check (public.is_admin());
drop policy if exists "Admins can update municipal budget" on public.municipal_budget;
create policy "Admins can update municipal budget"
  on public.municipal_budget for update
  using (public.is_admin());

drop policy if exists "Admins can insert barangay assemblies" on public.barangay_assemblies;
create policy "Admins can insert barangay assemblies"
  on public.barangay_assemblies for insert
  with check (public.is_admin());
drop policy if exists "Admins can update barangay assemblies" on public.barangay_assemblies;
create policy "Admins can update barangay assemblies"
  on public.barangay_assemblies for update
  using (public.is_admin());
drop policy if exists "Admins can delete barangay assemblies" on public.barangay_assemblies;
create policy "Admins can delete barangay assemblies"
  on public.barangay_assemblies for delete
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────
-- HOW TO MAKE SOMEONE AN ADMIN
-- Every new signup defaults to role='resident' (via the column default
-- above) — nobody is an admin until you explicitly promote them here.
-- Register the account normally through either app first (so the
-- profiles row exists), then run:
--
--   update public.profiles set role = 'admin' where email = 'someone@example.com';
-- ─────────────────────────────────────────────────────────
