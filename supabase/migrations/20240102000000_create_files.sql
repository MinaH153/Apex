-- Migration: files table with row-level security
-- Stores file metadata; actual blobs live in the "files" storage bucket.

create table public.files (
  id         uuid        primary key default gen_random_uuid(),
  owner_id   uuid        not null references auth.users (id) on delete cascade,
  name       text        not null,
  path       text        not null,
  size       bigint,
  mime_type  text,
  created_at timestamptz not null default now()
);

-- Enable RLS
alter table public.files enable row level security;

-- Policy: users can read only their own files
create policy "Users can read own files"
  on public.files
  for select
  using (auth.uid() = owner_id);

-- Policy: users can insert files they own
create policy "Users can insert own files"
  on public.files
  for insert
  with check (auth.uid() = owner_id);

-- Policy: users can delete only their own files
create policy "Users can delete own files"
  on public.files
  for delete
  using (auth.uid() = owner_id);
