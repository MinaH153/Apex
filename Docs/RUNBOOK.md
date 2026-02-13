# Apex Runbook

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| Docker Desktop | latest | https://www.docker.com/products/docker-desktop |
| Node.js | 18+ | `brew install node` or https://nodejs.org |
| Supabase CLI | latest | `brew install supabase/tap/supabase` |
| Xcode | 15+ | Mac App Store (iOS development only) |

Verify:

```bash
docker --version
node --version
supabase --version
```

---

## 1. Local Supabase Setup

All commands run from the project root (`/Apex`).

```bash
# Start all Supabase services (Postgres, Auth, Storage, Realtime, Studio)
supabase start

# Apply all migrations and seed data
supabase db reset
```

`supabase start` launches Docker containers. First run downloads images and takes a few minutes.

### Get the anon key

```bash
supabase status
```

Look for `anon key` in the output. You will need it for both web and iOS.

### Stop services

```bash
supabase stop
```

---

## 2. Web Setup (Next.js)

```bash
cd web

# Install dependencies
npm install

# Create env file (first time only)
cp .env.local.example .env.local
```

Edit `web/.env.local` and paste your anon key:

```
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<paste anon key from supabase status>
```

Start the dev server:

```bash
npm run dev
```

Open http://localhost:3000 in your browser.

---

## 3. iOS Setup (SwiftUI)

1. Open `ios/Apex.xcodeproj` in Xcode.
2. The Supabase URL and anon key are in `ios/Apex/Info.plist`:
   - `SUPABASE_URL` -- default: `http://localhost:54321`
   - `SUPABASE_ANON_KEY` -- default: the local dev demo key
3. For the iOS Simulator, `localhost` resolves correctly. No changes needed.
4. Select the `Apex` scheme and a simulator, then **Cmd+R** to build and run.

### ATS (App Transport Security)

`Info.plist` has an ATS exception allowing insecure HTTP to `localhost` only. This is for local development. Remove or scope it to Debug before shipping to production.

---

## 4. Environment Files Reference

| File | Variables | Notes |
|------|-----------|-------|
| `web/.env.local` | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Not committed to git |
| `ios/Apex/Info.plist` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Committed with dev defaults |
| `supabase/config.toml` | Ports, auth settings, storage limits | Committed |

---

## 5. Common Commands

```bash
# Reset DB (drops and recreates with all migrations)
supabase db reset

# Create a new migration
supabase migration new <name>

# View migration status
supabase migration list

# Open Supabase Studio (local dashboard)
open http://127.0.0.1:54323

# Tail Postgres logs
supabase db logs

# Check running services
supabase status
```

---

## 6. Production Checklist

Before deploying to a hosted Supabase project:

- [ ] Run `supabase db push` to apply migrations to the remote database
- [ ] Enable email confirmations in Auth settings (`enable_confirmations = true`)
- [ ] Rotate the default JWT secret and anon/service keys
- [ ] Remove or restrict ATS localhost exception in iOS `Info.plist`
- [ ] Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` to production values
- [ ] Update `SUPABASE_URL` and `SUPABASE_ANON_KEY` in iOS for production
- [ ] Review storage `file_size_limit` (currently 50 MiB)
- [ ] Enable analytics if needed (`[analytics] enabled = true`)
- [ ] Verify RLS policies are active on all tables (`SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';`)
- [ ] Test realtime subscriptions end-to-end with production credentials
- [ ] Set up database backups (point-in-time recovery)
- [ ] Configure rate limiting and abuse prevention

---

## 7. Troubleshooting

### Docker not running
```
Error: Cannot connect to the Docker daemon
```
Start Docker Desktop and wait for it to be ready, then retry `supabase start`.

### Port conflicts
```
Error: address already in use :::54321
```
Another process is using the port. Either stop it (`lsof -i :54321`) or change the port in `supabase/config.toml`.

### Migrations fail on reset
```
Error: ERROR: relation "..." already exists
```
Migrations must be idempotent or ordered correctly. Check for duplicate `CREATE TABLE` statements. Run `supabase db reset` for a clean slate.

### iOS cannot reach Supabase
- Ensure `supabase start` is running.
- Confirm `SUPABASE_URL` in `Info.plist` is `http://localhost:54321`.
- Check the ATS exception for `localhost` is present in `Info.plist`.
- On a physical device, use your Mac's local IP instead of `localhost`.

### Web shows "Invalid API key"
- Verify `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `web/.env.local` matches `supabase status` output.
- Restart the Next.js dev server after changing `.env.local`.

### Realtime not working
- Confirm `[realtime] enabled = true` in `supabase/config.toml`.
- Verify the table is in the publication: `SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';`
- Check the browser/Xcode console for WebSocket errors.

### Storage upload fails
- Confirm the bucket exists: `SELECT * FROM storage.buckets;`
- Verify the file path follows the `{user_id}/{filename}` convention.
- Check RLS policies on `storage.objects` allow the current user.
