# Supabase migrations (backend Phase 0)

Schema and Row-Level Security for the HTMLStudio backend migration. See
`docs/BACKEND_MIGRATION_PLAN.md` for the full plan.

## Apply

```bash
# with the Supabase CLI, from the repo root:
supabase db push          # applies migrations/*.sql in order
# or paste each file into the Supabase SQL editor, 0001 then 0002.
```

## Files

- `migrations/0001_init.sql` — tables (profiles, teams, team_members, projects,
  templates, blocks, user_settings) mapping today's localStorage blobs.
- `migrations/0002_rls.sql` — Row-Level Security so each user only reaches their
  own data. The admin panel uses a separate service-role API and bypasses RLS
  by design (see `docs/ADMIN_PANEL_SPEC.md`).

## Not yet wired

The client still runs in `mode: 'local'` (see `WebApp/datastore.js`). Phase 2/3
adds a remote adapter that talks to these tables; nothing here is live until
then. Applying these migrations against an empty Supabase project is safe and
idempotent-ish (guards with `if not exists`).
