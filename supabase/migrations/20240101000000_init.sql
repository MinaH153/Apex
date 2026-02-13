-- Initial migration: profiles table with row-level security
-- Every authenticated user gets a profile row linked to auth.users.

create table public.profiles (
  id           uuid        primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now()
);

-- Enable RLS
alter table public.profiles enable row level security;

-- Policy: users can read only their own profile
create policy "Users can read own profile"
  on public.profiles
  for select
  using (auth.uid() = id);

-- Policy: users can update only their own profile
create policy "Users can update own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Policy: users can insert their own profile (for signup flows)
create policy "Users can insert own profile"
  on public.profiles
  for insert
  with check (auth.uid() = id);
