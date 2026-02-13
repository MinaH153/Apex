# Supabase Agent Memory

## Project: Apex

- Project ID in config.toml: "apex"
- DB major version: 15
- Local ports: API 54321, DB 54322, Studio 54323, Inbucket 54324

## Schema

- `public.profiles` table: id (uuid PK -> auth.users), display_name (text), created_at (timestamptz)
  - RLS: select/update/insert restricted to own row via auth.uid() = id
- `public.files` table: id (uuid PK, gen_random_uuid()), owner_id (uuid FK -> auth.users), name (text), path (text), size (bigint), mime_type (text), created_at (timestamptz)
  - RLS: select/insert/delete restricted to own rows via auth.uid() = owner_id (no UPDATE policy)
  - Realtime: added to supabase_realtime publication

## Storage

- Bucket "files" (private, not public)
  - Path convention: {user_id}/{filename}
  - RLS on storage.objects: select/insert/delete using storage.foldername(name)[1] = auth.uid()::text
  - No UPDATE policy on storage.objects

## Conventions

- Migrations live in supabase/migrations/ with timestamp prefix (YYYYMMDDHHMMSS_name.sql)
- seed.sql runs after migrations on `supabase db reset`
- All policies follow least-privilege (own-row only by default)
