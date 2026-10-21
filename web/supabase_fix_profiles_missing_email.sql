-- FIX: the real project's `profiles` table was missing an `email` column
-- that the mobile app's own registration code (auth_provider.dart
-- register()) already tries to write on every signup. Without it, that
-- insert silently failed every time (caught and logged as "will retry
-- after OTP"), which meant completeRegistration()'s later UPDATE had no
-- row to update either — so no profile row ever got created, and logging
-- in afterward failed too (_loadProfile()'s .single() query found nothing).
--
-- Already applied directly to the project via the Management API on
-- [today's date] — this file documents the change for the team / repo
-- history. Safe to re-run (idempotent).

alter table public.profiles add column if not exists email text;
