-- Run after schema.sql, admin_schema.sql and citizen_reports_status_tracking.sql.
-- Apply in Supabase SQL Editor before using the updated admin dashboard.
begin;
alter table public.citizen_reports
  add column if not exists verification_status text not null default 'pending',
  add column if not exists verification_note text not null default '',
  add column if not exists reviewed_by uuid references auth.users(id),
  add column if not exists reviewed_at timestamptz;
-- Preserve reports already being handled. Re-running does not reset decisions.
update public.citizen_reports set verification_status = 'verified'
where verification_status = 'pending' and reviewed_at is null
  and status in ('assigned', 'in_progress', 'resolved', 'closed');
alter table public.citizen_reports drop constraint if exists citizen_reports_verification_check;
alter table public.citizen_reports add constraint citizen_reports_verification_check
  check (verification_status in ('pending', 'verified', 'needs_information', 'rejected'));

create table if not exists public.citizen_report_reviews (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.citizen_reports(id) on delete cascade,
  reviewer_id uuid references auth.users(id),
  decision text not null,
  note text not null,
  severity text,
  created_at timestamptz not null default now()
);
alter table public.citizen_report_reviews enable row level security;
drop policy if exists "Admins read report reviews" on public.citizen_report_reviews;
create policy "Admins read report reviews" on public.citizen_report_reviews
  for select to authenticated using (public.is_admin());

create or replace function public.guard_citizen_report_verification()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'INSERT' then
    -- New citizen submissions cannot mark themselves verified or assigned.
    if auth.uid() is not null and not public.is_admin() then
      new.verification_status := 'pending';
      new.verification_note := '';
      new.reviewed_by := null;
      new.reviewed_at := null;
      new.status := 'received';
    end if;
  else
    if auth.uid() is not null and not public.is_admin() then
      raise exception 'Only an administrator can update a report';
    end if;
    if new.verification_status is distinct from old.verification_status
       or new.verification_note is distinct from old.verification_note
       or new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or (new.verification_status = 'verified' and new.severity is distinct from old.severity) then
      if auth.uid() is not null and not public.is_admin() then
        raise exception 'Only an administrator can review a report';
      end if;
      if new.verification_status in ('rejected', 'needs_information')
         and length(trim(new.verification_note)) = 0 then
        raise exception 'A reason or information request is required';
      end if;
      if new.verification_status = 'verified' and coalesce(new.severity, '') not in ('Low', 'Medium', 'High') then
        raise exception 'Choose a final severity before verifying';
      end if;
      new.reviewed_by := auth.uid();
      new.reviewed_at := now();
    end if;
  end if;
  if new.status in ('assigned', 'in_progress', 'resolved', 'closed')
     and new.verification_status <> 'verified' then
    raise exception 'Verify this report before assigning or progressing it';
  end if;
  return new;
end $$;
drop trigger if exists citizen_reports_guard_verification on public.citizen_reports;
create trigger citizen_reports_guard_verification before insert or update on public.citizen_reports
  for each row execute function public.guard_citizen_report_verification();

create or replace function public.audit_citizen_report_verification()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.verification_status is distinct from old.verification_status
     or new.verification_note is distinct from old.verification_note
     or (new.verification_status = 'verified' and new.severity is distinct from old.severity) then
    insert into public.citizen_report_reviews(report_id, reviewer_id, decision, note, severity)
      values(new.id, new.reviewed_by, new.verification_status, new.verification_note, new.severity);
    -- Status changes already have their own notification trigger.
    if new.status is not distinct from old.status then
      insert into public.notifications(user_id, title, message, type, data)
      values(new.user_id, 'Report verification update',
        case new.verification_status
          when 'verified' then 'Your report has been verified.'
          when 'rejected' then 'Your report was rejected: ' || new.verification_note
          when 'needs_information' then 'More information is needed: ' || new.verification_note
          else 'Your report is awaiting verification.' end,
        'citizen_report', jsonb_build_object('report_id', new.id, 'verification_status', new.verification_status));
    end if;
  end if;
  return new;
end $$;
drop trigger if exists citizen_reports_audit_verification on public.citizen_reports;
create trigger citizen_reports_audit_verification after update on public.citizen_reports
  for each row execute function public.audit_citizen_report_verification();
commit;
