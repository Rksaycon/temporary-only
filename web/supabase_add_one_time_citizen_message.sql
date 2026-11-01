-- Adds one permanent, admin-authored citizen message to each report.
-- Safe to run more than once. Existing reports and notifications are kept.

begin;

alter table public.citizen_reports
  add column if not exists citizen_message text,
  add column if not exists citizen_message_sent_at timestamptz,
  add column if not exists citizen_message_sent_by uuid references auth.users(id);

alter table public.citizen_reports
  drop constraint if exists citizen_reports_citizen_message_length;
alter table public.citizen_reports
  add constraint citizen_reports_citizen_message_length
  check (
    citizen_message is null
    or (length(trim(citizen_message)) between 1 and 1000)
  );

create or replace function public.send_one_time_citizen_report_message(
  p_report_id uuid,
  p_message text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_user_id uuid;
  sent_time timestamptz;
  row_updated_at timestamptz;
  clean_message text := trim(coalesce(p_message, ''));
  report_reference text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only administrators can message a citizen report';
  end if;

  if length(clean_message) < 1 or length(clean_message) > 1000 then
    raise exception 'Message must contain between 1 and 1000 characters';
  end if;

  update public.citizen_reports
  set citizen_message = clean_message,
      citizen_message_sent_at = now(),
      citizen_message_sent_by = auth.uid()
  where id = p_report_id
    and citizen_message_sent_at is null
  returning user_id, citizen_message_sent_at, updated_at
    into target_user_id, sent_time, row_updated_at;

  if not found then
    if exists (
      select 1 from public.citizen_reports where id = p_report_id
    ) then
      raise exception 'A citizen message has already been sent for this report';
    end if;
    raise exception 'Report not found';
  end if;

  if target_user_id is null then
    raise exception 'This report is not linked to a citizen account';
  end if;

  report_reference := 'RPT-' || upper(left(replace(p_report_id::text, '-', ''), 8));

  insert into public.notifications (user_id, title, message, type, data)
  values (
    target_user_id,
    'Barangay message about ' || report_reference,
    clean_message,
    'citizen_report',
    jsonb_build_object(
      'report_id', p_report_id,
      'reference', report_reference,
      'action', 'admin_message'
    )
  );

  return jsonb_build_object(
    'message', clean_message,
    'sent_at', sent_time,
    'updated_at', row_updated_at
  );
end
$$;

revoke all on function public.send_one_time_citizen_report_message(uuid, text)
  from public, anon;
grant execute on function public.send_one_time_citizen_report_message(uuid, text)
  to authenticated;

commit;
