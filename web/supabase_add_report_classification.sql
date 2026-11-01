-- Adds an admin-verified incident classification without overwriting the
-- category originally selected by the citizen.
--
-- Run this in the Supabase SQL Editor AFTER:
--   mobile/supabase/citizen_reports_verification.sql
--
-- Existing meaning after this migration:
--   category                       citizen-reported category
--   ai_detected_image_category     independent AI photo classification
--   verified_category              final admin classification

begin;

alter table public.citizen_reports
  add column if not exists verified_category text;

-- Existing verified reports only had category, so preserve their current
-- official classification as the migration baseline.
update public.citizen_reports
set verified_category = category
where verification_status = 'verified'
  and nullif(trim(verified_category), '') is null;

alter table public.citizen_report_reviews
  add column if not exists final_category text;

alter table public.citizen_reports
  drop constraint if exists citizen_reports_verified_category_check;

alter table public.citizen_reports
  add constraint citizen_reports_verified_category_check
  check (
    verification_status <> 'verified'
    or nullif(trim(verified_category), '') is not null
  );

-- A classification correction on an already-verified report is itself an
-- admin review action, so update the reviewer metadata as well.
create or replace function public.guard_report_classification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verified_category is distinct from old.verified_category then
    if auth.uid() is not null and not public.is_admin() then
      raise exception 'Only administrators can verify report classifications';
    end if;
    new.reviewed_by := auth.uid();
    new.reviewed_at := now();
    new.updated_at := now();
  end if;

  if new.verification_status = 'verified'
     and nullif(trim(new.verified_category), '') is null then
    raise exception 'Select a final classification before verifying';
  end if;

  return new;
end
$$;

drop trigger if exists citizen_reports_guard_classification
  on public.citizen_reports;
create trigger citizen_reports_guard_classification
  before update of verification_status, verified_category
  on public.citizen_reports
  for each row execute function public.guard_report_classification();

-- Extend the existing verification audit to include the final category.
create or replace function public.audit_report_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verification_status is distinct from old.verification_status
     or new.verification_note is distinct from old.verification_note
     or (
       new.verification_status = 'verified'
       and (
         new.severity is distinct from old.severity
         or new.verified_category is distinct from old.verified_category
       )
     ) then
    insert into public.citizen_report_reviews(
      report_id,
      reviewer_id,
      decision,
      note,
      severity,
      final_category
    ) values (
      new.id,
      new.reviewed_by,
      new.verification_status,
      new.verification_note,
      new.severity,
      new.verified_category
    );

    -- Status changes already have their own notification trigger.
    if new.status is not distinct from old.status then
      insert into public.notifications(user_id, title, message, type, data)
      values (
        new.user_id,
        'Report verification update',
        case new.verification_status
          when 'verified' then
            'Your report was verified as ' || new.verified_category || '.'
          when 'rejected' then
            'Your report was rejected: ' || new.verification_note
          when 'needs_information' then
            'More information is needed: ' || new.verification_note
          else 'Your report is awaiting verification.'
        end,
        'citizen_report',
        jsonb_build_object(
          'report_id', new.id,
          'verification_status', new.verification_status,
          'verified_category', new.verified_category
        )
      );
    end if;
  end if;

  return new;
end
$$;

commit;
