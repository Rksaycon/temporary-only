-- Adds the profiles table may_laud's registration/auth flow expects,
-- matching the exact shape used in auth_provider.dart (User.fromJson,
-- register(), completeRegistration(), updateProfile()) and the role
-- column from the IS team's own supabase_add_role_column.sql. Run this in
-- the same test project as supabase_setup_for_testing.sql.

create table if not exists public.profiles (
  id          uuid primary key references auth.users(id),
  name        text,
  email       text,
  phone       text,
  address     text,
  avatar_url  text,
  role        text not null default 'resident',
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles for select to authenticated
  using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update to authenticated
  using (auth.uid() = id);
