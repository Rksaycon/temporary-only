-- Run this in Supabase Dashboard → SQL Editor.
-- Grants the web admin panel (any authenticated user, since there's no
-- separate admin role column yet) permission to write to the tables it
-- manages. Read/select policies are left untouched — only add them if a
-- table currently has none and residents/admins can't read it either.

-- Announcements
create policy "Authenticated users can insert announcements"
  on announcements for insert to authenticated with check (true);
create policy "Authenticated users can update announcements"
  on announcements for update to authenticated using (true);
create policy "Authenticated users can delete announcements"
  on announcements for delete to authenticated using (true);

-- Citizen reports (residents insert their own; admin updates status on any)
create policy "Authenticated users can update citizen reports"
  on citizen_reports for update to authenticated using (true);

-- Document requests (residents insert their own; admin updates status on any)
create policy "Authenticated users can update document requests"
  on document_requests for update to authenticated using (true);

-- Hotlines
create policy "Authenticated users can insert hotlines"
  on hotlines for insert to authenticated with check (true);
create policy "Authenticated users can update hotlines"
  on hotlines for update to authenticated using (true);
create policy "Authenticated users can delete hotlines"
  on hotlines for delete to authenticated using (true);

-- Flood alerts
create policy "Authenticated users can insert flood alerts"
  on flood_alerts for insert to authenticated with check (true);
create policy "Authenticated users can update flood alerts"
  on flood_alerts for update to authenticated using (true);
