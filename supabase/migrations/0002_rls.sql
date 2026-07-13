-- HTMLStudio — backend migration Phase 0: Row-Level Security
-- Isolation is a DATABASE guarantee, not app-layer trust. Customer clients use
-- the anon/authenticated role and are bound by these policies. The admin panel
-- uses a separate service-role API (audited) and bypasses RLS by design.

alter table profiles      enable row level security;
alter table teams         enable row level security;
alter table team_members  enable row level security;
alter table projects      enable row level security;
alter table templates     enable row level security;
alter table blocks        enable row level security;
alter table user_settings enable row level security;

-- Profiles: a user sees/edits only their own profile row.
create policy "own profile" on profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

-- Teams: visible to members; only the owner can mutate top-level team rows.
create policy "team read"  on teams for select
  using (owner_id = auth.uid()
         or id in (select team_id from team_members where user_id = auth.uid()));
create policy "team write" on teams for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Team membership: visible to members of that team.
create policy "membership read" on team_members for select
  using (user_id = auth.uid()
         or team_id in (select team_id from team_members m where m.user_id = auth.uid()));

-- Projects: owner, or any member of the project's team.
create policy "own or team projects" on projects for all
  using (
    owner_id = auth.uid()
    or team_id in (select team_id from team_members where user_id = auth.uid())
  ) with check (
    owner_id = auth.uid()
    or team_id in (select team_id from team_members where user_id = auth.uid())
  );

-- Library + settings: strictly per-owner.
create policy "own templates" on templates for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "own blocks" on blocks for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "own settings" on user_settings for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
