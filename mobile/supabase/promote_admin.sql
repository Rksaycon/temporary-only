-- Promotes an account to admin, creating its profiles row if one
-- doesn't already exist (covers both cases: the trigger from
-- web_admin_compat.sql firing correctly, and it not having existed yet
-- when this particular account signed up).

insert into public.profiles (id, email, role, is_verified, name)
select id, email, 'admin', true, coalesce(raw_user_meta_data->>'name', '')
from auth.users
where email = 'jelinetorres21@gmail.com'
on conflict (id) do update set role = 'admin', is_verified = true;

-- Confirm it worked:
select id, email, role, is_verified from public.profiles where email = 'jelinetorres21@gmail.com';
