-- Adds AI triage columns to citizen_reports: severity auto-classification
-- and image verification, provided by the CS team's ML backend
-- (jus1012-triage-delro-api.hf.space). Run this in Supabase Dashboard →
-- SQL Editor.
--
-- Design note: severity is split into an AI-suggested value and the final
-- value, same pattern used for everything else this backend classifies —
-- the AI proposes, a human (resident at submission time, or an admin
-- later) can override, and both are kept so it's visible when that
-- happened. `severity` is what the app actually displays/filters on;
-- `ai_suggested_severity` is kept for transparency/audit, not shown as the
-- "real" value.

-- 1. Severity (currently the mobile app's priority picker exists in the UI
--    but is never actually saved — this both adds the column AND is what
--    submitReport() needs to start writing to, in app_services.dart).
alter table public.citizen_reports
  add column if not exists severity text;
alter table public.citizen_reports
  add column if not exists ai_suggested_severity text;
alter table public.citizen_reports
  add column if not exists ai_severity_confidence numeric;

-- 2. Image verification (from the first photo in photo_urls, if any).
alter table public.citizen_reports
  add column if not exists ai_detected_image_category text;
alter table public.citizen_reports
  add column if not exists ai_image_valid boolean;
alter table public.citizen_reports
  add column if not exists requires_manual_review boolean not null default false;

-- No RLS changes needed — citizen_reports already has an insert policy for
-- residents (their own reports) and an update policy for authenticated
-- admins (supabase_admin_policies.sql), and these are just additional
-- columns on rows those policies already cover.
