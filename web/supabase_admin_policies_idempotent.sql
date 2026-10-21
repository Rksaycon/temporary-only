-- Safe to run multiple times: each policy is wrapped so an "already exists"
-- error is silently skipped instead of stopping the whole script.
-- Run this in Supabase Dashboard → SQL Editor.

do $$
begin
  begin
    create policy "Authenticated users can insert announcements"
      on public.announcements for insert to authenticated with check (true);
  exception when duplicate_object then null; end;

  begin
    create policy "Authenticated users can update announcements"
      on public.announcements for update to authenticated using (true);
  exception when duplicate_object then null; end;

  begin
    create policy "Authenticated users can delete announcements"
      on public.announcements for delete to authenticated using (true);
  exception when duplicate_object then null; end;

  -- Citizen reports: residents can already insert their own (per your schema).
  -- Admin needs to update status on ANY resident's report.
  begin
    create policy "Authenticated users can update citizen reports"
      on public.citizen_reports for update to authenticated using (true);
  exception when duplicate_object then null; end;

  -- Document requests: same idea — admin updates status on any request.
  begin
    create policy "Authenticated users can update document requests"
      on public.document_requests for update to authenticated using (true);
  exception when duplicate_object then null; end;

  -- Hotlines: your schema only has a read policy — admin needs write access.
  begin
    create policy "Authenticated users can insert hotlines"
      on public.hotlines for insert to authenticated with check (true);
  exception when duplicate_object then null; end;

  begin
    create policy "Authenticated users can update hotlines"
      on public.hotlines for update to authenticated using (true);
  exception when duplicate_object then null; end;

  begin
    create policy "Authenticated users can delete hotlines"
      on public.hotlines for delete to authenticated using (true);
  exception when duplicate_object then null; end;

  -- Flood alerts: same — only a read policy exists in your schema.
  begin
    create policy "Authenticated users can insert flood alerts"
      on public.flood_alerts for insert to authenticated with check (true);
  exception when duplicate_object then null; end;

  begin
    create policy "Authenticated users can update flood alerts"
      on public.flood_alerts for update to authenticated using (true);
  exception when duplicate_object then null; end;
end $$;
