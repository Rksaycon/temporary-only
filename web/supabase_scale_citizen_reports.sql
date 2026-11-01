-- Scalable admin queue for Citizen Reports.
-- Run after supabase_add_report_classification.sql.
-- The web page automatically falls back to its legacy query until this RPC
-- exists, so this migration can be reviewed before it is installed.

begin;

create index if not exists citizen_reports_admin_queue_idx
  on public.citizen_reports (
    verification_status,
    status,
    severity,
    created_at desc
  );

create index if not exists citizen_reports_verified_category_idx
  on public.citizen_reports (verified_category, created_at desc);

create index if not exists citizen_reports_ai_category_idx
  on public.citizen_reports (ai_detected_image_category, created_at desc);

create index if not exists citizen_reports_manual_review_idx
  on public.citizen_reports (created_at desc)
  where requires_manual_review = true or ai_image_valid = false;

create or replace function public.normalize_report_category(value text)
returns text
language sql
immutable
parallel safe
as $$
  select case lower(trim(coalesce(value, '')))
    when 'fire' then 'Fire'
    when 'flood' then 'Flooding'
    when 'flooding' then 'Flooding'
    when 'medical' then 'Medical Emergency'
    when 'medical emergency' then 'Medical Emergency'
    when 'infrastructure' then 'Infrastructure Damage'
    when 'infrastructure damage' then 'Infrastructure Damage'
    when 'earthquake' then 'Earthquake'
    when 'landslide' then 'Landslide'
    when 'sanitation' then 'Sanitation'
    when 'security' then 'Security'
    when 'traffic' then 'Traffic'
    when 'environment' then 'Environment'
    when 'health' then 'Health'
    when 'others' then 'Other'
    when 'other' then 'Other'
    else trim(coalesce(value, ''))
  end
$$;

create or replace function public.is_ml_supported_report_category(value text)
returns boolean
language sql
immutable
parallel safe
as $$
  select public.normalize_report_category(value) in (
    'Fire',
    'Flooding',
    'Medical Emergency',
    'Infrastructure Damage'
  )
$$;

create or replace function public.admin_list_citizen_reports_v2(
  p_queue text default 'needs_attention',
  p_status text default 'all',
  p_severity text default 'all',
  p_classification text default 'all',
  p_verification text default 'all',
  p_search text default '',
  p_limit integer default 25,
  p_offset integer default 0
)
returns table(report jsonb, total_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Administrator access required';
  end if;

  return query
  with matching as (
    select
      cr as report_row,
      p.name as profile_name,
      p.email as profile_email,
      p.phone as profile_phone,
      public.normalize_report_category(
        coalesce(
          nullif(trim(cr.verified_category), ''),
          cr.category,
          nullif(trim(cr.ai_detected_image_category), '')
        )
      ) as effective_category,
      (
        public.normalize_report_category(cr.category) in ('Fire', 'Flooding')
        and cr.requires_manual_review is distinct from true
        and
        cr.ai_image_valid is distinct from false
        and nullif(trim(cr.category), '') is not null
        and nullif(trim(cr.ai_detected_image_category), '') is not null
        and public.normalize_report_category(cr.category)
          <> public.normalize_report_category(cr.ai_detected_image_category)
      ) as classification_mismatch
    from public.citizen_reports cr
    left join public.profiles p on p.id = cr.user_id
    where
      case coalesce(p_queue, 'needs_attention')
        when 'needs_attention' then
          coalesce(cr.verification_status, 'pending') = 'needs_information'
          or (
            coalesce(cr.verification_status, 'pending') = 'pending'
            and (
              coalesce(public.normalize_report_category(cr.category), '') not in ('Fire', 'Flooding')
              or cr.requires_manual_review = true
              or cr.ai_image_valid = false
              or nullif(trim(cr.ai_detected_image_category), '') is null
              or public.normalize_report_category(cr.category)
                <> public.normalize_report_category(cr.ai_detected_image_category)
            )
          )
        when 'ready' then
          coalesce(cr.verification_status, 'pending') = 'pending'
          and cr.requires_manual_review is distinct from true
          and public.normalize_report_category(cr.category) in ('Fire', 'Flooding')
          and cr.ai_image_valid is distinct from false
          and nullif(trim(cr.ai_detected_image_category), '') is not null
          and public.normalize_report_category(cr.category)
            = public.normalize_report_category(cr.ai_detected_image_category)
        when 'active' then cr.status in ('assigned', 'in_progress')
        when 'completed' then
          cr.status in ('resolved', 'closed')
          or cr.verification_status = 'rejected'
        else true
      end
      and case coalesce(p_status, 'all')
        when 'all' then true
        when 'outstanding' then
          cr.status not in ('resolved', 'closed')
          and cr.verification_status <> 'rejected'
        when 'active' then cr.status in ('assigned', 'in_progress')
        when 'resolved' then cr.status in ('resolved', 'closed')
        when 'rejected' then cr.verification_status = 'rejected'
        else cr.status = p_status
      end
      and case coalesce(p_severity, 'all')
        when 'all' then true
        when 'unassigned' then nullif(trim(cr.severity), '') is null
        else cr.severity = p_severity
      end
      and case coalesce(p_verification, 'all')
        when 'all' then true
        else cr.verification_status = p_verification
      end
      and case coalesce(p_classification, 'all')
        when 'all' then true
        when 'mismatch' then
          public.normalize_report_category(cr.category) in ('Fire', 'Flooding')
          and cr.requires_manual_review is distinct from true
          and
          cr.ai_image_valid is distinct from false
          and nullif(trim(cr.ai_detected_image_category), '') is not null
          and public.normalize_report_category(cr.category)
            <> public.normalize_report_category(cr.ai_detected_image_category)
        when 'corroborated' then
          public.normalize_report_category(cr.category) in ('Fire', 'Flooding')
          and cr.requires_manual_review is distinct from true
          and cr.ai_image_valid is distinct from false
          and nullif(trim(cr.ai_detected_image_category), '') is not null
          and public.normalize_report_category(cr.category)
            = public.normalize_report_category(cr.ai_detected_image_category)
        when 'learning_mode' then
          public.normalize_report_category(cr.category)
            in ('Medical Emergency', 'Infrastructure Damage')
          and cr.requires_manual_review is distinct from true
          and cr.ai_image_valid is distinct from false
          and nullif(trim(cr.ai_detected_image_category), '') is not null
        when 'manual_review' then
          public.is_ml_supported_report_category(cr.category)
          and (
            cr.requires_manual_review = true
            or cr.ai_image_valid = false
            or nullif(trim(cr.ai_detected_image_category), '') is null
          )
        when 'awaiting_ai' then
          public.is_ml_supported_report_category(cr.category)
          and nullif(trim(cr.ai_detected_image_category), '') is null
        when 'community_concern' then
          not public.is_ml_supported_report_category(cr.category)
        else public.normalize_report_category(
          coalesce(
            nullif(trim(cr.verified_category), ''),
            cr.category,
            nullif(trim(cr.ai_detected_image_category), '')
          )
        ) = public.normalize_report_category(p_classification)
      end
      and (
        nullif(trim(coalesce(p_search, '')), '') is null
        or cr.description ilike '%' || trim(p_search) || '%'
        or cr.location ilike '%' || trim(p_search) || '%'
        or cr.category ilike '%' || trim(p_search) || '%'
        or cr.subcategory ilike '%' || trim(p_search) || '%'
        or coalesce(p.name, '') ilike '%' || trim(p_search) || '%'
        or coalesce(p.email, '') ilike '%' || trim(p_search) || '%'
      )
  ),
  counted as (
    select matching.*, count(*) over() as match_count
    from matching
  )
  select
    to_jsonb(c.report_row)
      || jsonb_build_object(
        'profiles', jsonb_build_object(
          'name', c.profile_name,
          'email', c.profile_email,
          'phone', c.profile_phone
        ),
        'effective_category', c.effective_category,
        'classification_mismatch', c.classification_mismatch,
        'ai_classification_applicable',
          public.is_ml_supported_report_category((c.report_row).category)
      ) as report,
    c.match_count as total_count
  from counted c
  order by
    case
      when (c.report_row).status in ('resolved', 'closed')
        or (c.report_row).verification_status = 'rejected'
      then 1 else 0
    end,
    case (c.report_row).severity
      when 'High' then 0
      when 'Medium' then 1
      when 'Low' then 2
      else 3
    end,
    (c.report_row).created_at desc
  limit greatest(1, least(coalesce(p_limit, 25), 100))
  offset greatest(coalesce(p_offset, 0), 0);
end
$$;

revoke all on function public.admin_list_citizen_reports_v2(
  text, text, text, text, text, text, integer, integer
) from public;
grant execute on function public.admin_list_citizen_reports_v2(
  text, text, text, text, text, text, integer, integer
) to authenticated;

create or replace function public.admin_citizen_report_queue_counts()
returns table(queue text, total_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Administrator access required';
  end if;

  return query
  with reports as (
    select
      cr.*,
      public.is_ml_supported_report_category(cr.category) as ml_supported,
      public.normalize_report_category(cr.category) as reported_category,
      public.normalize_report_category(cr.ai_detected_image_category) as detected_category
    from public.citizen_reports cr
  )
  select counts.queue, counts.total_count
  from (
    select 'needs_attention'::text as queue, count(*)::bigint as total_count
    from reports
    where coalesce(verification_status, 'pending') = 'needs_information'
      or (
        coalesce(verification_status, 'pending') = 'pending'
        and (
          coalesce(reported_category, '') not in ('Fire', 'Flooding')
          or requires_manual_review = true
          or ai_image_valid = false
          or nullif(trim(ai_detected_image_category), '') is null
          or reported_category <> detected_category
        )
      )

    union all
    select 'ready', count(*)::bigint
    from reports
    where coalesce(verification_status, 'pending') = 'pending'
      and requires_manual_review is distinct from true
      and reported_category in ('Fire', 'Flooding')
      and ai_image_valid is distinct from false
      and nullif(trim(ai_detected_image_category), '') is not null
      and reported_category = detected_category

    union all
    select 'active', count(*)::bigint
    from reports
    where status in ('assigned', 'in_progress')

    union all
    select 'completed', count(*)::bigint
    from reports
    where status in ('resolved', 'closed') or verification_status = 'rejected'

    union all
    select 'all', count(*)::bigint from reports
  ) counts;
end
$$;

revoke all on function public.admin_citizen_report_queue_counts() from public;
grant execute on function public.admin_citizen_report_queue_counts() to authenticated;

commit;
