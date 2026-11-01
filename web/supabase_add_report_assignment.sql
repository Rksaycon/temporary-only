-- Adds internal responsible-office routing to citizen reports.
-- Run after supabase_add_report_classification.sql. This migration is
-- self-contained for projects that do not yet have the mobile status helper.

begin;

-- Cleanup for the short-lived dispatch simulation prototype, if it was ever
-- installed. Unused columns are intentionally left in place to avoid deleting
-- any data; only its workflow-enforcement trigger/function are removed.
drop trigger if exists citizen_reports_enforce_dispatch_transition
  on public.citizen_reports;
drop function if exists public.citizen_reports_enforce_dispatch_transition();

alter table public.citizen_reports
  add column if not exists assigned_department text,
  add column if not exists assigned_at timestamptz;

alter table public.citizen_reports
  drop constraint if exists citizen_reports_assigned_department_length;
alter table public.citizen_reports
  add constraint citizen_reports_assigned_department_length
  check (assigned_department is null or char_length(assigned_department) <= 200);

create or replace function public.citizen_reports_status_label(status text)
returns text
language sql
immutable
set search_path = public
as $$
  select case lower(coalesce(status, ''))
    when 'received'    then 'Received'
    when 'assigned'    then 'Assigned'
    when 'in_progress' then 'Ongoing'
    when 'resolved'    then 'Resolved'
    when 'closed'      then 'Closed'
    else initcap(coalesce(status, 'received'))
  end;
$$;

-- Include the real office in resident notifications. A department-only
-- correction also sends an update even when the status stays "assigned".
create or replace function public.citizen_reports_notify_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ref_label text;
  old_label text;
  new_label text;
  notification_message text;
begin
  if old.status is not distinct from new.status
     and old.assigned_department is not distinct from new.assigned_department then
    return new;
  end if;

  ref_label := 'RPT-' || upper(substr(replace(new.id::text, '-', ''), 1, 8));
  old_label := public.citizen_reports_status_label(old.status);
  new_label := public.citizen_reports_status_label(new.status);

  if new.status = 'assigned' and nullif(trim(new.assigned_department), '') is not null then
    notification_message := 'Your report ' || ref_label || ' was routed internally to '
      || new.assigned_department || '. This does not confirm emergency-service dispatch.';
  else
    notification_message := 'Your report ' || ref_label || ' moved from '
      || old_label || ' to ' || new_label || '.';
  end if;

  insert into public.notifications (user_id, title, message, type, data)
  values (
    new.user_id,
    'Report update — ' || new_label,
    notification_message,
    'citizen_report',
    jsonb_build_object(
      'type', 'citizen_report',
      'report_id', new.id::text,
      'status', new.status,
      'reference', ref_label,
      'assigned_department', new.assigned_department
    )
  );

  return new;
end;
$$;

drop trigger if exists citizen_reports_notify_status_change
  on public.citizen_reports;
create trigger citizen_reports_notify_status_change
  after update of status, assigned_department on public.citizen_reports
  for each row
  when (
    old.status is distinct from new.status
    or old.assigned_department is distinct from new.assigned_department
  )
  execute function public.citizen_reports_notify_status_change();

commit;
