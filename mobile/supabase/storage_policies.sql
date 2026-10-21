-- Run this AFTER creating the 'report-photos' bucket manually in the
-- Storage tab (Storage → New bucket → name "report-photos" → Public: ON).
-- Also create the 'document-attachments' bucket the same way
-- (Public: ON) — DocumentRequestsProvider.submitRequest() uploads there.
-- Safe to re-run.

drop policy if exists "Anyone can view report photos" on storage.objects;
drop policy if exists "Users can upload their own report photos" on storage.objects;
drop policy if exists "Anyone can view document attachments" on storage.objects;
drop policy if exists "Users can upload their own document attachments" on storage.objects;

create policy "Anyone can view report photos"
  on storage.objects for select
  using (bucket_id = 'report-photos');

-- Upload path is '<uid>/<timestamp>_<n>.jpg' — this restricts uploads to
-- each resident's own folder (see submitReport() in app_services.dart).
create policy "Users can upload their own report photos"
  on storage.objects for insert
  with check (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Anyone can view document attachments"
  on storage.objects for select
  using (bucket_id = 'document-attachments');

-- Upload path is '<uid>/<timestamp>_<n>.jpg' — restricts uploads to each
-- resident's own folder (see submitRequest() in content_providers.dart).
create policy "Users can upload their own document attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'document-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
