-- Migration: enable Realtime (Postgres Changes) on the files table
alter publication supabase_realtime add table public.files;
