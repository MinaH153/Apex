# Supabase Agent Memory

## Project Structure
- Config: `supabase/config.toml` (project_id="apex", PG 15, realtime+storage enabled)
- Migrations dir: `supabase/migrations/`
- 6 migrations total (20240101 through 20240106)

## Schema
- `public.profiles`: id (uuid PK -> auth.users), display_name, created_at
- `public.files`: id (uuid PK), owner_id (FK -> auth.users), name, path, size, mime_type, created_at
  - Indexes: owner_id, (owner_id, created_at DESC)
  - Constraints: UNIQUE(owner_id, path), CHECK(size >= 0)
- Storage bucket: "files" (private), path convention: `{user_id}/{filename}`
- Realtime: files table added to supabase_realtime publication

## RLS Summary (audited 2026-02-13)
- profiles: SELECT/UPDATE/INSERT own only, no DELETE (intentional)
- files: SELECT/INSERT/DELETE own only, no UPDATE (intentional, immutable)
- storage.objects: SELECT/INSERT/DELETE scoped by bucket_id + foldername[1], no UPDATE (immutable uploads)

## Key Ports (local dev)
- API: 54321, DB: 54322, Studio: 54323, Inbucket: 54324

## Docs
- Runbook: `Docs/RUNBOOK.md` (local dev, web/iOS setup, production checklist, troubleshooting)
