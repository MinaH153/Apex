-- Migration: "files" storage bucket with RLS policies
-- File path convention: {user_id}/{filename}

-- Create the bucket (private, not public)
insert into storage.buckets (id, name, public)
values ('files', 'files', false);

-- Policy: users can read objects in their own folder
create policy "Users can read own files"
  on storage.objects
  for select
  using (
    bucket_id = 'files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: users can upload objects to their own folder
create policy "Users can upload own files"
  on storage.objects
  for insert
  with check (
    bucket_id = 'files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: users can delete objects from their own folder
create policy "Users can delete own files"
  on storage.objects
  for delete
  using (
    bucket_id = 'files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
