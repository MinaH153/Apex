# Supabase SP1 + SP2 + SP3 Plan

## SP1: Audit DB RLS + Storage RLS

**Audit Results** (all 4 migrations reviewed):

1. `profiles` table (20240101000000_init.sql):
   - SELECT: `USING (auth.uid() = id)` -- correct
   - UPDATE: `USING (auth.uid() = id) WITH CHECK (auth.uid() = id)` -- correct
   - INSERT: `WITH CHECK (auth.uid() = id)` -- correct
   - No DELETE policy -- intentional (profiles persist)

2. `files` table (20240102000000_create_files.sql):
   - SELECT: `USING (auth.uid() = owner_id)` -- correct
   - INSERT: `WITH CHECK (auth.uid() = owner_id)` -- correct
   - DELETE: `USING (auth.uid() = owner_id)` -- correct
   - No UPDATE policy -- intentional (immutable metadata)

3. Storage bucket (20240103000000_create_storage_bucket.sql):
   - Bucket is private (`public = false`) -- correct
   - SELECT: `USING (bucket_id = 'files' AND auth.uid()::text = (storage.foldername(name))[1])` -- correct
   - INSERT: `WITH CHECK (bucket_id = 'files' AND auth.uid()::text = (storage.foldername(name))[1])` -- correct
   - DELETE: `USING (bucket_id = 'files' AND auth.uid()::text = (storage.foldername(name))[1])` -- correct
   - No UPDATE policy -- intentional (immutable uploads)

4. Realtime (20240104000000_enable_files_realtime.sql):
   - Adds `files` to `supabase_realtime` publication -- correct
   - RLS still applies to realtime subscriptions

**Verdict**: All policies are already least-privilege. No migration needed. Will create an audit-only migration with documentation comments.

## SP2: Add indexes + constraints

Create migration `20240105000000_files_indexes_constraints.sql`:
1. `CREATE INDEX idx_files_owner_id ON public.files (owner_id);`
2. `CREATE INDEX idx_files_owner_created ON public.files (owner_id, created_at DESC);`
3. `ALTER TABLE public.files ADD CONSTRAINT uq_files_owner_path UNIQUE (owner_id, path);`
4. `ALTER TABLE public.files ADD CONSTRAINT chk_files_size_non_negative CHECK (size >= 0);`

## SP3: Write Docs/RUNBOOK.md

Cover:
- Prerequisites (Docker, Node >= 18, Xcode 15+, Supabase CLI)
- Local dev setup (`supabase start`, `supabase db reset`)
- How to get anon key (`supabase status`)
- Environment files (web .env.local, iOS Info.plist)
- Web setup (`npm install && npm run dev`)
- iOS setup (open .xcodeproj, set scheme, run)
- Production checklist
- Troubleshooting common issues

## Files to create/modify
- `supabase/migrations/20240105000000_rls_audit.sql` (comment-only audit doc)
- `supabase/migrations/20240106000000_files_indexes_constraints.sql` (SP2)
- `Docs/RUNBOOK.md` (SP3)
