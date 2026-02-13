-- Migration: indexes and constraints for public.files
-- Improves query performance and enforces data integrity.

-- 1. Index on owner_id (used by RLS checks and direct queries)
create index idx_files_owner_id
  on public.files (owner_id);

-- 2. Composite index for the list-files query: WHERE owner_id = ? ORDER BY created_at DESC
create index idx_files_owner_created
  on public.files (owner_id, created_at desc);

-- 3. Prevent duplicate uploads: same owner cannot have the same path twice
alter table public.files
  add constraint uq_files_owner_path unique (owner_id, path);

-- 4. File size must be non-negative (NULL is allowed for metadata-only rows)
alter table public.files
  add constraint chk_files_size_non_negative check (size >= 0);
