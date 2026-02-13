# Supabase (Apex Backend)

Owned by the **supabase** agent. All schema, RLS, realtime, and storage config lives here.

## Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started) installed
- [Docker](https://docs.docker.com/get-docker/) running

## Quick Start

```bash
# Start the local Supabase stack (Postgres, Auth, Studio, etc.)
supabase start

# Apply all migrations and seed data from scratch
supabase db reset

# Open Studio in your browser (default: http://127.0.0.1:54323)
```

## Project Structure

```
supabase/
  config.toml                          -- CLI and local dev settings
  seed.sql                             -- Seed data (runs on db reset)
  migrations/
    20240101000000_init.sql            -- Profiles table + RLS policies
    20240102000000_create_files.sql    -- Files table + RLS policies
    20240103000000_create_storage_bucket.sql -- Storage bucket "files" + RLS
    20240104000000_enable_files_realtime.sql -- Realtime on files table
```

## Key Ports (local)

| Service  | Port  |
|----------|-------|
| API      | 54321 |
| Database | 54322 |
| Studio   | 54323 |
| Inbucket | 54324 |

## Creating New Migrations

```bash
supabase migration new <migration_name>
```

This generates a timestamped SQL file in `migrations/`. Write your DDL there.

## Realtime Subscriptions

The `public.files` table is published to `supabase_realtime`, so clients receive live Postgres Changes events.

### JavaScript / TypeScript

```js
const channel = supabase
  .channel('files')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'files',
      filter: `owner_id=eq.${userId}`,
    },
    (payload) => {
      console.log('Change received:', payload);
    }
  )
  .subscribe();
```

### Swift (supabase-swift)

```swift
let channel = supabase.channel("files")

let changes = channel.postgresChange(
    AnyAction.self,
    schema: "public",
    table: "files",
    filter: "owner_id=eq.\(userId)"
)

await channel.subscribe()

for await change in changes {
    print("Change received:", change)
}
```

Filter by `owner_id` so each client only receives events for their own files. RLS on the table also enforces this server-side.
