-- HTMLStudio — backend migration Phase 0: schema
-- See docs/BACKEND_MIGRATION_PLAN.md. Run against a Supabase Postgres project.
-- Maps today's localStorage blobs (aurora-users.v1, aurora-editor.v1) to tables.

create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- App profile for each auth.users row (Supabase manages credentials/MFA).
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  email       text not null,
  plan        text not null default 'free',
  created_at  timestamptz not null default now()
);

-- Multi-tenant unit (enables Teams + the admin panel in Phase 4).
create table if not exists teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  owner_id    uuid not null references profiles(id),
  created_at  timestamptz not null default now()
);

create table if not exists team_members (
  team_id     uuid references teams(id) on delete cascade,
  user_id     uuid references profiles(id) on delete cascade,
  role        text not null default 'member',   -- owner|admin|member|readonly
  created_at  timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- Builder projects (was builderProjects[] inside aurora-editor.v1).
create table if not exists projects (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references profiles(id) on delete cascade,
  team_id     uuid references teams(id) on delete set null,
  name        text not null,
  design      jsonb not null default '{}'::jsonb,  -- { dir, pageBg, preheader, utm, blocks[] }
  status      text not null default 'active',      -- active|archived|deleted
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);
create index if not exists projects_owner_idx on projects(owner_id);
create index if not exists projects_team_idx  on projects(team_id);

-- Reusable library (was templates[] / myBlocks[]).
create table if not exists templates (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references profiles(id) on delete cascade,
  name        text not null,
  design      jsonb,
  html        text,
  updated_at  timestamptz not null default now()
);

create table if not exists blocks (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references profiles(id) on delete cascade,
  name        text not null,
  type        text not null,
  props       jsonb not null default '{}'::jsonb
);

-- Per-user preferences (was settings / utm* / imagekit / emailRelay / favorites).
create table if not exists user_settings (
  user_id     uuid primary key references profiles(id) on delete cascade,
  settings    jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- Keep updated_at fresh on write.
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end $$ language plpgsql;

drop trigger if exists projects_touch on projects;
create trigger projects_touch      before update on projects      for each row execute function set_updated_at();
drop trigger if exists templates_touch on templates;
create trigger templates_touch     before update on templates     for each row execute function set_updated_at();
drop trigger if exists user_settings_touch on user_settings;
create trigger user_settings_touch before update on user_settings for each row execute function set_updated_at();
