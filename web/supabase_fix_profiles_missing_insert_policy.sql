-- FIX: the real project's `profiles` table had RLS enabled with a SELECT
-- and an UPDATE policy, but no INSERT policy — so every new registration's
-- initial profile-creation upsert (auth_provider.dart register()) was
-- silently blocked ("new row violates row-level security policy"), caught
-- by that function's own try/catch. No profile row ever got created, which
-- meant completeRegistration()'s later UPDATE had nothing to update either,
-- and logging in afterward failed too (_loadProfile()'s .single() query
-- found no row for that user).
--
-- Already applied directly to the project via the Management API. This
-- file documents the change for the team / repo history. Safe to re-run.

drop policy if exists "Users insert own profile" on public.profiles;
create policy "Users insert own profile"
  on public.profiles for insert to authenticated
  with check (auth.uid() = id);
