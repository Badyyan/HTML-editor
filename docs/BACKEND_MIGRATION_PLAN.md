# HTMLStudio — Backend & Auth Migration Plan

> **Why this exists:** every "next level" feature — cross-device sync, real accounts, teams, the admin
> panel — is blocked on one thing: HTMLStudio has no server. This is the concrete, phased plan to move
> off browser-only storage onto a real backend **without breaking the working app or losing anyone's
> work.**

---

## 1. Current state (grounded in the code)

Everything lives in the visitor's browser. There is no server, no database, no cross-device anything.

| localStorage key | Owner | Contents |
|---|---|---|
| `aurora-users.v1` | `WebApp/auth.js` | Accounts: `{ name, email, salt, hash, algo:'pbkdf2', iterations, createdAt, resetCode?, resetExpires? }` |
| `aurora-session` | `WebApp/auth.js` | Current session: `{ name, email, ts }` (presence = "logged in") |
| `aurora-theme` | all pages | `light` / `dark` |
| `aurora-editor.v1` | `editor.html` `loadStore/saveStore` | The workspace: `settings`, `session.tabs`, `templates`, `myBlocks`, `favorites`, `utmShortcuts/utmDefaults/utmPresets/utmHistory`, `builderProjects`, `builderCurrentId`, `builderDesign`, `imagekit`, `assetsRecent`, `emailRelay` |

**Consequences to fix:** accounts are per-browser (no sync, no recovery beyond same device); "security"
is front-end only; passwords are salted PBKDF2 hashes (good, but **not reversible** — this matters for
migration); nothing is shareable or team-owned.

The good news: the code already isolates the seams. Auth is one file (`auth.js`), and all workspace
persistence funnels through two functions (`loadStore` / `saveStore`). That's exactly where the swap
happens.

---

## 2. Target architecture

```
Browser (existing static app, mostly unchanged UI)
   │  data-layer abstraction (new, thin)
   ▼
Supabase  ──► Postgres (users, teams, projects, workspace data)  + Row-Level Security
   ├────────► Auth (email/password, OAuth, magic link, MFA)
   └────────► Storage (exported HTML, assets)   [optional]
Cloudflare Workers (existing: ImageKit relay, email relay) stay as-is
Vercel (existing static hosting) stays as-is
```

### Provider recommendation

| Option | Verdict | Why |
|---|---|---|
| **Supabase** (recommended for V1) | ✅ | One vendor gives Auth **+ Postgres + RLS + Storage**. Postgres is the foundation the admin-panel spec assumes. RLS enforces per-user isolation at the DB, which becomes the base for admin elevation. Generous free tier; SQL you own. |
| **Clerk + separate Postgres (Neon)** | ✅ alt | Best-in-class auth UX and enterprise SSO sooner, but you still stand up and wire a database yourself. Choose this if premium auth/SSO is a near-term selling point. |
| **Auth.js (NextAuth) + Postgres** | ⚠ | Most control, most glue code. Only if you're already moving the frontend to Next.js. |

The rest of this plan is written for **Supabase**; the phases are identical for Clerk+Neon (only the
auth SDK calls differ).

---

## 3. Postgres schema (maps today's blobs → tables)

```sql
-- Auth users are managed by Supabase in auth.users; this is the app profile.
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  email       text not null,
  plan        text not null default 'free',
  created_at  timestamptz not null default now()
);

-- Multi-tenant unit (enables teams + the admin panel later).
create table teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  owner_id    uuid not null references profiles(id),
  created_at  timestamptz not null default now()
);
create table team_members (
  team_id     uuid references teams(id) on delete cascade,
  user_id     uuid references profiles(id) on delete cascade,
  role        text not null default 'member',      -- owner|admin|member|readonly
  primary key (team_id, user_id)
);

-- Builder projects (was builderProjects[] in aurora-editor.v1).
create table projects (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references profiles(id),
  team_id     uuid references teams(id),
  name        text not null,
  design      jsonb not null,                       -- the block design (utm, blocks, …)
  status      text not null default 'active',       -- active|archived|deleted
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

-- Reusable library (was templates[] / myBlocks[]).
create table templates ( id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id), name text, design jsonb, html text, updated_at timestamptz default now());
create table blocks    ( id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id), name text, type text, props jsonb );

-- Per-user preferences (was settings / utm* / imagekit / emailRelay).
create table user_settings (
  user_id uuid primary key references profiles(id) on delete cascade,
  settings jsonb not null default '{}'    -- theme, editor prefs, utm presets, integration config
);
```

> Keep the `design`/`props` as `jsonb` — the block model already *is* JSON, so migration is a copy, and
> the schema doesn't churn every time a block type is added.

---

## 4. Row-Level Security (the isolation foundation)

RLS is what makes "users only see their own data" a database guarantee, not app-layer trust — and it's
the hook the admin panel later uses for elevated access.

```sql
alter table projects enable row level security;

-- A user can read/write their own projects, or projects in a team they belong to.
create policy "own or team projects" on projects
  for all using (
    owner_id = auth.uid()
    or team_id in (select team_id from team_members where user_id = auth.uid())
  ) with check (
    owner_id = auth.uid()
    or team_id in (select team_id from team_members where user_id = auth.uid())
  );
```

Admin access is **not** a looser RLS policy — admins go through the separate, server-side admin API
(service role, audited) described in `ADMIN_PANEL_SPEC.md`, never the customer client.

---

## 5. The one client change that matters: a data-layer seam

Today the app calls `loadStore()/saveStore()` and `AuroraAuth.*` directly. Introduce a thin `dataStore`
abstraction so the UI doesn't care whether data is local or remote. This lets you ship the backend
**behind a flag** and roll back instantly.

```js
// dataStore.js — the single seam. UI code calls these, not localStorage.
const dataStore = {
  mode: 'local',                 // 'local' | 'remote', chosen at runtime / by flag
  async getProjects()      { … } // local: read aurora-editor.v1 · remote: supabase.from('projects')
  async saveProject(p)     { … }
  async getSettings()      { … }
  async saveSettings(s)    { … }
  // …templates, blocks, session…
};
```

Refactor targets (small, mechanical):
- `auth.js` → `AuroraAuth` methods delegate to Supabase Auth when `mode === 'remote'` (the file already
  documents "swap the storage calls in this one file").
- `editor.html` `loadStore/saveStore` and the builder's `persist()` → call `dataStore`, with localStorage
  kept as an **offline cache** (write-through) so the app still works offline and feels instant.

---

## 6. Migrating existing accounts and work (the honest part)

Two different problems, two different answers:

**Passwords — cannot be carried over.** They're salted PBKDF2 hashes, deliberately irreversible, and in
a format Supabase/Clerk won't accept. So on cutover, existing users **re-establish credentials** via a
one-time email verification / "set your password" flow (or just sign up again). This is unavoidable and
normal for an auth-provider migration — communicate it clearly.

**Their work — must not be lost, and can be imported.** A user's designs/templates/presets sit in
`aurora-editor.v1` **on the same browser**. On first login to the new system, show a one-time banner:
*"We found designs saved in this browser — import them to your account?"* → read localStorage, POST to
the API, done. Additive and safe (never deletes local data; re-runnable).

```
First remote login →
  if (localStorage['aurora-editor.v1'] has projects/templates) and not alreadyImported:
     offer "Import N designs from this browser"
     on accept: upload to /projects, /templates, /settings ; mark imported
```

---

## 7. Phased rollout (each phase is shippable and reversible)

| Phase | Goal | Key work | Reversible? |
|---|---|---|---|
| **0. Foundation** | Supabase project live | Create project; run schema + RLS; seed plans; wire env/secrets. No app change yet. | n/a |
| **1. Seam** | `dataStore` abstraction merged, still `mode:'local'` | Refactor `loadStore/saveStore`, `persist()`, `AuroraAuth` to route through `dataStore`. Behaviour identical today. | ✅ trivially |
| **2. Real auth** | Supabase Auth behind a flag | Replace `AuroraAuth` internals; keep the same UI (login/signup/reset pages already exist). Add the "import from this browser" flow. Flag: `%` rollout. | ✅ flip flag |
| **3. Remote data** | Projects/templates/settings sync to Postgres | `dataStore.mode='remote'` write-through with localStorage cache; conflict rule = last-write-wins per project (fine for single-user V1). | ✅ per-user flag |
| **4. Multi-tenant + admin base** | Teams + service-role admin API | Add teams/members, team-scoped RLS, and the separate admin API surface → unblocks the admin panel. | forward-only |

Ship 0→3 to get **real accounts + cross-device sync** (the headline user win). Phase 4 is the gate for
the admin panel and can follow once tenancy is needed.

---

## 8. Security & compliance carried over

- **RLS on every user table** (isolation is a DB guarantee).
- **Supabase Auth** brings email verification, password reset, OAuth, and **MFA** for free — retire the
  client-side `auth.js` crypto entirely (it was always documented as non-enforcing).
- Keep the **CSP / sandbox / header hardening** already shipped; add `connect-src` for the Supabase URL.
- **Secrets** (Supabase service role, provider keys) stay server-side only — never in the client bundle.
- GDPR: export + delete become real (server-side) instead of "clear your browser."

---

## 9. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Data loss during cutover | Import is additive; localStorage never wiped; write-through cache; per-user rollback flag. |
| Users frustrated by password reset | Clear comms + one-click email reset; frame as a security upgrade. |
| Sync conflicts | V1 is single-user per project → last-write-wins is safe; real CRDT/merge is a V2 concern. |
| Vendor lock-in | It's plain Postgres + standard SQL; Supabase is exportable; the `dataStore` seam isolates SDK calls. |
| Scope creep into "rebuild everything" | Phases 0–3 change *storage*, not the product UI. The editor/builder stay as-is. |

---

## 10. Effort snapshot (rough, one engineer)

- Phase 0–1 (foundation + seam): ~3–5 days
- Phase 2 (auth + import flow): ~4–6 days
- Phase 3 (remote data sync): ~5–8 days
- Phase 4 (teams + admin API base): ~1–2 weeks

**≈ 3–4 weeks to real accounts + sync + the foundation the admin panel needs** — without touching the
editor/builder UX you've already polished.

---

### TL;DR
Stand up Supabase (Auth + Postgres + RLS) → introduce one `dataStore` seam so the UI is storage-agnostic
→ flip auth and data to remote behind a flag, importing each user's browser-saved work on first login.
Three-ish weeks gets cross-device accounts; one more gets the multi-tenant base the admin panel sits on.
Nothing you've built gets thrown away.
