-- Metadata-only inventory for an authorized Supabase SQL session.
-- No mutations, secret values, citizen rows, or storage object names.
-- Review output locally; grants shown can depend on the querying role.

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname in ('public', 'storage')
order by schemaname, tablename, policyname;

select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('public', 'storage') and c.relkind in ('r', 'p')
order by 1, 2;

select table_schema, table_name, grantee, privilege_type
from information_schema.table_privileges
where table_schema in ('public', 'storage')
order by 1, 2, 3, 4;

select table_schema, table_name, column_name, grantee, privilege_type
from information_schema.column_privileges
where table_schema = 'public'
  and table_name in ('profiles', 'citizen_reports', 'citizen_report_reviews')
order by 1, 2, 3, 4, 5;

select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer, p.proconfig as function_settings,
       p.proacl as explicit_acl,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by 1, 2, 3;

select event_object_schema, event_object_table, trigger_name,
       event_manipulation, action_timing, action_statement
from information_schema.triggers
where event_object_schema = 'public'
order by 1, 2, 3, 4;

select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id in ('report-photos', 'document-attachments')
order by id;
