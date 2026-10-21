-- Makes the Mylaud project (enojnhijfabncaeoyctt) compatible with what
-- Maylaud_Web's existing React code already assumes — without touching
-- anything the Flutter app or admin_schema.sql already set up.
--
-- Everything else Maylaud_Web's own SQL files add (email column on
-- profiles, an insert policy on profiles, the `role` column, the AI
-- triage columns on citizen_reports) is already present in this
-- project's schema.sql / admin_schema.sql — do NOT run
-- supabase_fix_profiles_missing_email.sql,
-- supabase_fix_profiles_missing_insert_policy.sql,
-- supabase_add_role_column.sql, or supabase_add_ai_triage_columns.sql
-- from that repo here; they're redundant. Do NOT run
-- supabase_admin_policies.sql or supabase_admin_policies_idempotent.sql
-- either — those grant ANY authenticated user (not just admins) write
-- access, which would sit alongside admin_schema.sql's proper
-- role-gated policies and defeat them (Postgres RLS policies are OR'd
-- together — the more permissive one wins).
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → New query → paste this
-- whole file → Run. Safe to re-run.

-- ─────────────────────────────────────────────────────────
-- is_verified column — AuthContext.jsx's signUp()/completeSignupProfile()
-- set this after signup / OTP verification, but nothing in this
-- project's schema created it yet.
-- ─────────────────────────────────────────────────────────
alter table public.profiles add column if not exists is_verified boolean not null default false;

-- ─────────────────────────────────────────────────────────
-- Auto-create a profiles row on signup — AuthContext.jsx deliberately
-- never inserts a profiles row itself (its own comment: "no insert
-- policy on profiles for the client to use"), assuming a database
-- trigger does it instead. This project never had one; the Flutter
-- app's client-side upsert calls (register()/completeRegistration()/the
-- self-heal in _loadProfile()) have been covering for its absence.
-- Adding this doesn't change the Flutter app's behavior — an upsert
-- against a row this trigger already created just updates it — but it's
-- required for the web app's signup flow to work at all.
-- ─────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, phone, role, is_verified)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    new.email,
    new.raw_user_meta_data->>'phone',
    'resident',
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
