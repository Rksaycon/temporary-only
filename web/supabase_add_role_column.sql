-- Adds account-type separation between the web admin panel and the mobile
-- resident app. Run this in Supabase Dashboard → SQL Editor.

-- 1. Add the role column. Every EXISTING account (residents who already
--    signed up via the mobile app) defaults to 'resident', which is correct
--    for them and requires no action.
alter table public.profiles
  add column if not exists role text not null default 'resident';

-- 2. IMPORTANT — do this part manually, once, for each real admin account:
--    Find your admin user's id in Authentication → Users (or run the SELECT
--    below to look it up by email), then promote them to 'admin'. Until you
--    do this, NO ONE will be able to log into the web admin panel — new
--    signups through the web Sign Up page will set this automatically going
--    forward, but any admin accounts created BEFORE this migration need to
--    be promoted manually.

-- Look up a user's id by email:
-- select id, email from auth.users where email = 'admin@milaor.gov.ph';

-- Promote that user to admin:
-- update public.profiles set role = 'admin' where id = '<paste-the-id-here>';

-- 3. (Optional but recommended) restrict who can change the role column,
-- so a resident can't just edit their own profile row to grant themselves
-- admin access. This requires replacing the existing self-update policy
-- with one that excludes `role` from what a user can change themselves.
-- Only run this once you've confirmed the app itself never needs to let a
-- non-admin update their own role (it doesn't — only you, via SQL, should).
--
-- drop policy if exists "Users update own profile" on public.profiles;
-- create policy "Users update own profile (not role)"
--   on public.profiles for update
--   using (auth.uid() = id)
--   with check (auth.uid() = id and role = (select role from public.profiles where id = auth.uid()));
