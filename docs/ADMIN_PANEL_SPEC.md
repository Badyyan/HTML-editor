# HTMLStudio Admin Panel — V1 Product Specification

> **Status:** Blueprint. HTMLStudio today is a static, client-side app (accounts live in
> `localStorage`, no server). This spec describes the admin panel that becomes buildable once a
> real backend exists (auth provider + Postgres). It is written to be implemented directly, with a
> disciplined V1 scope and a clear V2 backlog.

---

## 0. Guiding principles

1. **Least privilege by default.** Every capability is denied unless a role explicitly grants it.
2. **Every write is audited.** No admin mutation happens outside the audit-log path.
3. **Ship the 20% that covers 80%.** V1 is operational safety (find a user, fix their account, see
   what's happening, bill them). Anything that can be a "manual query for now" is deferred.
4. **Read-heavy, mutation-guarded.** Most admin work is investigation; destructive actions require
   confirmation, reason capture, and (for the riskiest) a second signal (MFA re-auth / approval).
5. **The admin panel is a separate app/deployment** from the product, on its own subdomain
   (`admin.htmlstudio.app`), behind SSO + MFA + IP allowlist. It never ships in the customer bundle.

---

## 1. Recommended navigation / sidebar structure

```
HTMLStudio Admin
├── ⌂  Dashboard
├── 👤 Users
│    ├── All users
│    └── Sessions & login history
├── 🛡  Roles & Permissions
├── 👥 Teams
├── 📁 Projects
├── 📊 Usage & Analytics
├── 🤖 AI Management
│    ├── Usage & quotas
│    ├── Jobs & queue
│    └── API keys
├── 💳 Billing
├── 🛟 Support
│    ├── Tickets
│    └── Impersonation log
├── 🚩 Moderation
├── ⚙  System
│    ├── Feature flags
│    ├── Announcements
│    ├── Email templates
│    ├── Webhooks
│    └── Jobs & cache
├── 🧾 Audit Logs
├── 🐞 Error Monitoring
└── 💬 Feedback
```

Grouping rationale: top items are the daily-driver flows (Dashboard → Users → Projects → Billing).
System / Audit / Errors sit at the bottom as lower-frequency, higher-privilege areas. Nav items are
**hidden, not just disabled**, when the viewer's role lacks read access to that module.

---

## 2. Modules

Each module below follows: **Purpose · Core features · UI pages · Key actions · Permissions · Security · V2.**

### 2.1 Dashboard

- **Purpose:** One screen that answers "is the platform healthy and growing, and is anything on
  fire right now?"
- **Core features:** KPI tiles (total / active / verified / new / suspended users; projects created;
  AI token usage; MRR & revenue; system health); trend sparklines; recent activity feed; quick actions.
- **UI pages:** `/dashboard` (single page; date-range selector: 24h / 7d / 30d / custom).
- **Key actions:** Jump to any drill-down; run a quick action (find user, toggle maintenance mode,
  post announcement); acknowledge a health alert.
- **Permissions:** `dashboard.view`. Revenue tiles gated behind `billing.view`.
- **Security:** All figures are read-only aggregates from the read replica / analytics store — never
  live queries against production write DB. No PII on tiles (counts only).
- **V2:** Configurable/per-role dashboards, saved views, anomaly callouts, cohort retention widget.

### 2.2 User Management

- **Purpose:** Find any user and safely fix or moderate their account.
- **Core features:** Paginated table (search by email/id/name, filter by status/plan/verified/role/
  signup date, sort); user profile with tabs (Overview, Activity, Sessions, Billing, Projects, Notes);
  lifecycle actions.
- **UI pages:** `/users` (list), `/users/:id` (profile with tabs), `/users/sessions` (global session
  search).
- **Key actions:** verify/unverify · suspend · ban/unban · soft-delete · force password reset ·
  send email verification · resend invite · reset/disable MFA · revoke a session · revoke all sessions.
- **Permissions:** `users.view`, `users.edit`, `users.suspend`, `users.ban`, `users.delete`,
  `users.mfa.reset`, `users.session.revoke`. (Splitting `delete`/`ban` from `edit` is deliberate.)
- **Security:** Delete is **soft-delete** (30-day tombstone) → hard-delete is a separate, rarer,
  higher-privileged job. Destructive actions require a typed reason + confirmation; ban/delete require
  MFA re-auth. Never display password hashes, MFA secrets, or full tokens — only masked. All actions
  audited with before/after.
- **V2:** Bulk actions, saved segments, merge duplicate accounts, GDPR export/erase self-service.

### 2.3 Roles & Permissions (RBAC)

- **Purpose:** Control what admins can do, granularly, and let ops define custom roles without a deploy.
- **Core features:** Built-in roles (Super Admin, Admin, Manager, Team Member, Read-only); custom
  roles; permissions grouped by domain (Users, Billing, AI, System…); role → permission editor;
  "who has this role" view.
- **UI pages:** `/roles` (list + built-ins), `/roles/:id` (permission matrix editor), `/roles/assignments`.
- **Key actions:** create/clone/edit/delete custom role; toggle permissions in groups; assign role to
  admin; view effective permissions for a person.
- **Permissions:** `roles.view`, `roles.manage` (only Super Admin by default). A role can never grant a
  permission the editor doesn't themselves hold (**no privilege escalation**).
- **Security:** Permissions are enforced **server-side on every endpoint** (the UI hiding a button is
  cosmetic only). Changes are audited. Super Admin count is minimized and monitored.
- **V2:** Time-boxed / just-in-time role grants, approval workflow for sensitive grants, ABAC
  conditions (e.g. "Billing admin only for EU tenants").

### 2.4 Team Management

- **Purpose:** Administer customer teams/workspaces (the product's multi-tenant unit).
- **Core features:** Team list & search; team detail (members, roles, owner, plan, projects, settings);
  membership management.
- **UI pages:** `/teams`, `/teams/:id`.
- **Key actions:** create/edit team; invite/remove member; assign member role; transfer ownership;
  edit team settings/limits.
- **Permissions:** `teams.view`, `teams.edit`, `teams.members.manage`, `teams.transfer`.
- **Security:** Transfer ownership requires confirmation + audit and notifies both parties. Admin edits
  to customer teams are clearly attributed as staff actions in the customer's own activity log.
- **V2:** Team-level usage caps, team merge/split, seat management & proration hooks.

### 2.5 Project Management

- **Purpose:** Locate and administer any project (in HTMLStudio: a saved campaign/design).
- **Core features:** Global project search (by id/owner/team/name); project detail (owner, size,
  last edited, status); lifecycle.
- **UI pages:** `/projects`, `/projects/:id`.
- **Key actions:** open (read-only render) · archive · restore · transfer ownership · delete (soft).
- **Permissions:** `projects.view`, `projects.edit`, `projects.delete`, `projects.transfer`.
- **Security:** "Open project" renders content in a **sandboxed, no-same-origin iframe** (same rule the
  product's preview already enforces) — admins routinely view untrusted user HTML. Deletes are soft +
  audited.
- **V2:** Content diff/history, restore-to-point, storage reclamation reporting.

### 2.6 Usage & Analytics

- **Purpose:** Understand consumption and growth, per account and platform-wide.
- **Core features:** Per-user/team metrics (projects, storage, API calls, AI tokens, last active,
  login history); platform growth (signups, activation, retention); daily/weekly/monthly trends;
  CSV export.
- **UI pages:** `/analytics` (platform), plus embedded "Usage" tabs on user/team pages.
- **Key actions:** change date range/granularity; segment; export CSV.
- **Permissions:** `analytics.view`, `analytics.export`.
- **Security:** Served from an analytics/read-replica store, not production write DB. Exports are
  audited (data exfiltration is a real risk) and PII-minimized.
- **V2:** Funnels, cohort retention, forecasting, scheduled email reports, warehouse sync.

### 2.7 AI Management

- **Purpose:** Operate the AI subsystem: credits, quotas, models, jobs, cost, failures.
- **Core features:** Credit/token balances & adjustments; prompt/generation history (metadata-first,
  content gated); generated-file registry; per-plan/per-tenant model access; usage quotas; provider
  API-key management; job/queue monitor; failed-generation triage; cost tracking by model/tenant.
- **UI pages:** `/ai/usage`, `/ai/jobs`, `/ai/keys`, `/ai/models`.
- **Key actions:** grant/deduct credits; set quota; enable/disable a model per plan; rotate provider
  key; retry/cancel a job; inspect a failure.
- **Permissions:** `ai.view`, `ai.credits.manage`, `ai.quota.manage`, `ai.models.manage`,
  `ai.keys.manage`, `ai.jobs.manage`.
- **Security:** **Provider API keys are secrets** — stored in a vault/KMS, shown masked, never logged,
  rotation audited. Prompt content is sensitive/PII: default to metadata; viewing full content requires
  `ai.content.view` + is itself audited. Credit adjustments are audited with reason and reversible.
- **V2:** Live cost anomaly alerts, per-tenant rate shaping, prompt-safety review queue, model A/B config.

### 2.8 Billing

- **Purpose:** Resolve subscription and payment issues without leaving the admin panel.
- **Core features:** Subscription detail (plan, status, renewal, seats); plan changes; credits;
  refunds; cancel/reactivate; invoice history; payment status & failures.
- **UI pages:** `/billing/:accountId`, embedded "Billing" tab on user/team pages, `/billing/invoices`.
- **Key actions:** change plan; apply credit/coupon; issue refund; cancel/reactivate; retry payment;
  resend invoice.
- **Permissions:** `billing.view`, `billing.manage`, `billing.refund` (refund split out — highest risk).
- **Security:** **Never store raw card data** — the payment processor (Stripe) is the source of truth;
  the admin panel calls its API and mirrors state. Refunds require typed reason + amount confirmation +
  MFA re-auth, are idempotent, and audited. Reconcile via processor webhooks, not manual edits.
- **V2:** Dunning management, proration previews, tax/VAT handling, revenue analytics, chargeback flow.

### 2.9 Support Tools

- **Purpose:** Let support resolve tickets and safely act on behalf of users.
- **Core features:** Secure impersonation ("view as user"); account recovery; password reset; email
  verification; resend invites; per-user internal notes; internal ticket queue.
- **UI pages:** `/support/tickets`, `/support/tickets/:id`, impersonation launched from a user profile.
- **Key actions:** start/stop impersonation; recover account; reset password; verify email; add note;
  create/assign/resolve ticket.
- **Permissions:** `support.view`, `support.act`, `support.impersonate`.
- **Security (impersonation is the crown-jewel risk):**
  - Time-boxed (e.g. 30 min), explicit start/stop, **read-only by default**; write-mode impersonation
    is a separate permission and separately audited.
  - A persistent, unmissable banner ("You are viewing as <user>") in the impersonated session.
  - Every impersonated request is tagged with the acting admin id; the session token is distinct and
    scoped; MFA re-auth required to start; the user is notified per policy; fully audited (start, stop,
    every action).
  - Impersonation **cannot** be used to view another admin/Super Admin, change billing, or reset MFA.
- **V2:** Ticket SLAs, macros/canned replies, CSAT, knowledge-base linking, customer-facing status.

### 2.10 Moderation

- **Purpose:** Detect and act on abuse, spam, and policy violations.
- **Core features:** Flagged-account queue; abuse-report inbox; spam signals; rate-limit config &
  overrides; blocked-domain / blocked-IP lists; content-moderation action log.
- **UI pages:** `/moderation/queue`, `/moderation/reports`, `/moderation/rules` (rate limits, blocklists).
- **Key actions:** review & resolve a flag; ban/suspend from a report; add/remove blocked domain/IP;
  adjust rate limit; quarantine content.
- **Permissions:** `moderation.view`, `moderation.act`, `moderation.rules.manage`.
- **Security:** Blocklists are high-impact (can lock out legitimate users) → changes confirmed + audited
  + reversible. Moderator actions on content use the same sandboxed rendering as Projects.
- **V2:** ML spam scoring, auto-actions with human review, appeal workflow, shared threat intel.

### 2.11 System Administration

- **Purpose:** Operate the platform: flags, maintenance, comms, config, integrations, jobs, cache.
- **Core features:** Feature flags (global / per-plan / per-tenant / % rollout); maintenance mode;
  global announcements/banners; environment settings; email templates; webhook management (endpoints,
  secrets, deliveries, replay); background-job dashboard; cache management; system config.
- **UI pages:** `/system/flags`, `/system/announcements`, `/system/email-templates`,
  `/system/webhooks`, `/system/jobs`, `/system/cache`, `/system/config`.
- **Key actions:** toggle flag; enable maintenance mode; publish announcement; edit template (with
  preview + test send); create/rotate/replay webhook; retry/cancel job; purge cache key/namespace.
- **Permissions:** `system.view`, `system.flags.manage`, `system.maintenance`, `system.config.manage`,
  `system.webhooks.manage`, `system.jobs.manage`, `system.cache.manage`. Most default to Super Admin.
- **Security:** Maintenance mode + config changes are the blast-radius actions → confirmation + audit +
  ideally two-person review for prod config. Webhook secrets vaulted & masked. Env settings never expose
  secrets in the UI (write-only fields; show "set/unset"). Cache purge scoped, not "flush all" by default.
- **V2:** Config versioning + rollback, flag targeting rules UI, scheduled announcements, template i18n.

### 2.12 Audit Logs

- **Purpose:** A tamper-evident record of every administrative action.
- **Core features:** Immutable log of `who · when · action · resource · before → after · IP · user-agent`;
  full-text + faceted search (actor, resource, action, date, IP); per-resource history view; rollback
  where the action is reversible.
- **UI pages:** `/audit` (global search), plus a "History" tab on each resource.
- **Key actions:** search/filter; open an entry (full diff); export; **rollback** a reversible change.
- **Permissions:** `audit.view` (broad, read-only), `audit.export`, `audit.rollback` (narrow).
- **Security:** **Append-only / write-once** (no admin can edit or delete audit records; enforced at the
  DB/storage layer — e.g. a separate append-only store or WORM bucket). Logs are themselves a read that's
  logged for sensitive queries. Retention per compliance (e.g. ≥1 year for SOC 2). Rollback is itself an
  audited action.
- **V2:** SIEM streaming, integrity hashing/Merkle chaining, alerting on suspicious admin patterns.

### 2.13 Error Monitoring

- **Purpose:** Surface and triage application/AI/API/queue/webhook failures.
- **Core features:** Aggregated error stream (grouped by fingerprint); AI-failure, API-failure,
  queue-failure, webhook-failure views; search/filter; alert rules.
- **UI pages:** `/errors` (list + detail), `/errors/alerts`. In practice, **integrate an existing
  tool (Sentry) and embed/deep-link** rather than rebuild it.
- **Key actions:** view/group/assign/resolve/mute an error; configure alert; link to the affected
  user/job.
- **Permissions:** `errors.view`, `errors.manage`.
- **Security:** Scrub PII/secrets from stack traces and payloads at ingestion. Alert routing (Slack/
  PagerDuty) config is audited.
- **V2:** Correlation with deploys/releases, error-budget/SLO tracking, auto-grouping tuning.

### 2.14 Feedback Management

- **Purpose:** Capture and route user feedback, feature requests, and bug reports.
- **Core features:** Unified inbox (type: feedback / feature / bug); status tracking (New → Triaged →
  Planned → Done / Won't do); assignment to staff; link to the reporting user.
- **UI pages:** `/feedback` (board or table), `/feedback/:id`.
- **Key actions:** triage; set status; assign; tag; reply/notify; merge duplicates.
- **Permissions:** `feedback.view`, `feedback.manage`.
- **Security:** Treat submitted content as untrusted (escape on render). Rate-limit intake to prevent
  spam.
- **V2:** Public roadmap/voting, changelog publishing, duplicate detection, product-analytics linkage.

---

## 3. Database entities

Relational (PostgreSQL). Names are indicative; every table carries `id (uuid)`, `created_at`,
`updated_at`, and soft-deletable tables carry `deleted_at`.

| Entity | Key fields | Notes |
|---|---|---|
| `users` | email, name, status(`active/suspended/banned/deleted`), email_verified_at, plan_id | Product users. |
| `admin_users` | email, sso_subject, mfa_enabled | **Separate** from product users; admins are not product users. |
| `sessions` | user_id, ip, user_agent, created_at, last_seen_at, revoked_at | Product + admin sessions. |
| `mfa_factors` | user_id, type(`totp/webauthn`), secret_ref(vault) | Secret stored in vault, only a reference here. |
| `roles` | name, is_builtin | Built-ins seeded; custom roles editable. |
| `permissions` | key (`users.ban`…), group | Static catalog. |
| `role_permissions` | role_id, permission_id | Many-to-many. |
| `admin_role_assignments` | admin_user_id, role_id | Who is what. |
| `teams` | name, owner_user_id, plan_id, settings(jsonb) | Customer workspace. |
| `team_members` | team_id, user_id, role | Membership + product-side role. |
| `projects` | owner_id/team_id, name, status(`active/archived/deleted`), size_bytes, last_edited_at | HTMLStudio designs/campaigns. |
| `subscriptions` | account_id, processor_id, plan, status, renews_at, seats | Mirror of Stripe. |
| `invoices` | subscription_id, amount, status, processor_invoice_id | Mirror; PDF via processor. |
| `credit_ledger` | account_id, delta, reason, actor_id | Append-only credits/tokens ledger. |
| `ai_jobs` | account_id, model, status, tokens_in/out, cost, error | Queue/generation records. |
| `ai_keys` | provider, label, secret_ref(vault), status | Provider keys; secret vaulted. |
| `usage_events` | account_id, type, quantity, occurred_at | Raw metering → rolled up in analytics store. |
| `feature_flags` | key, scope(`global/plan/tenant`), value, rollout_pct | Runtime config. |
| `announcements` | title, body, audience, starts_at, ends_at | Global banners. |
| `email_templates` | key, subject, html, version | Versioned. |
| `webhooks` | url, event_types, secret_ref, status | + `webhook_deliveries` for attempts/replay. |
| `moderation_flags` | subject_type, subject_id, reason, status, resolver_id | Queue. |
| `blocklists` | type(`ip/domain`), value, reason, actor_id | High-impact; audited. |
| `support_tickets` | user_id, assignee_id, status, priority | + `ticket_messages`. |
| `user_notes` | user_id, author_id, body | Internal-only. |
| `impersonation_sessions` | admin_id, target_user_id, mode(`read/write`), started_at, ended_at | Fully audited. |
| `feedback` | user_id, type, status, assignee_id, body | Feedback/requests/bugs. |
| `audit_log` | actor_id, action, resource_type, resource_id, before(jsonb), after(jsonb), ip, ua | **Append-only.** |
| `errors` | fingerprint, source(`app/ai/api/queue/webhook`), count, status | Or delegate to Sentry. |

---

## 4. API design (REST)

Conventions: base `/api/admin/v1`; JSON; cursor pagination (`?cursor=&limit=`); every mutation returns
the audit-log id; every request carries the admin's scoped JWT; permission enforced server-side per route.

| Module | Endpoints (representative) |
|---|---|
| Dashboard | `GET /dashboard/summary?range=` |
| Users | `GET /users` · `GET /users/:id` · `PATCH /users/:id` · `POST /users/:id/suspend|ban|unban|verify|delete` · `POST /users/:id/password-reset` · `POST /users/:id/mfa/reset` · `GET /users/:id/sessions` · `DELETE /sessions/:id` · `POST /users/:id/sessions/revoke-all` |
| Roles | `GET /roles` · `POST /roles` · `PATCH /roles/:id` · `DELETE /roles/:id` · `GET /permissions` · `POST /admins/:id/roles` |
| Teams | `GET /teams` · `GET /teams/:id` · `PATCH /teams/:id` · `POST /teams/:id/members` · `DELETE /teams/:id/members/:uid` · `POST /teams/:id/transfer` |
| Projects | `GET /projects` · `GET /projects/:id` · `POST /projects/:id/archive|restore|transfer` · `DELETE /projects/:id` |
| Analytics | `GET /analytics/overview` · `GET /analytics/users/:id/usage` · `POST /analytics/export` |
| AI | `GET /ai/usage` · `POST /ai/accounts/:id/credits` · `PATCH /ai/accounts/:id/quota` · `GET /ai/jobs` · `POST /ai/jobs/:id/retry|cancel` · `GET/POST /ai/keys` · `POST /ai/keys/:id/rotate` · `PATCH /ai/models/:id` |
| Billing | `GET /billing/:accountId` · `POST /billing/:accountId/plan` · `POST /billing/:accountId/credit` · `POST /billing/:accountId/refund` · `POST /billing/:accountId/cancel|reactivate` · `GET /billing/invoices` |
| Support | `GET/POST /support/tickets` · `PATCH /support/tickets/:id` · `POST /users/:id/impersonation` · `DELETE /impersonation/:id` · `POST /users/:id/notes` |
| Moderation | `GET /moderation/flags` · `POST /moderation/flags/:id/resolve` · `GET/POST/DELETE /moderation/blocklists` · `PATCH /moderation/rate-limits` |
| System | `GET/PATCH /system/flags` · `POST /system/maintenance` · `GET/POST /system/announcements` · `GET/PUT /system/email-templates/:key` · `GET/POST /system/webhooks` · `POST /system/webhooks/:id/replay` · `GET /system/jobs` · `POST /system/cache/purge` |
| Audit | `GET /audit` · `GET /audit/:id` · `POST /audit/:id/rollback` |
| Errors | `GET /errors` · `PATCH /errors/:id` (or proxy Sentry) |
| Feedback | `GET /feedback` · `PATCH /feedback/:id` |

> **GraphQL alternative:** viable and nice for the deeply-nested profile pages, but REST is recommended
> for V1 — simpler per-route authorization, caching, and audit interception.

---

## 5. Permissions matrix (by built-in role)

`✔` = full · `R` = read-only · `—` = none. Custom roles compose any subset of the underlying permissions.

| Capability | Super Admin | Admin | Manager | Team Member | Read-only |
|---|:--:|:--:|:--:|:--:|:--:|
| Dashboard | ✔ | ✔ | ✔ | R | R |
| Users — view | ✔ | ✔ | ✔ | R | R |
| Users — edit/verify | ✔ | ✔ | ✔ | — | — |
| Users — suspend/ban | ✔ | ✔ | — | — | — |
| Users — delete | ✔ | — | — | — | — |
| Users — MFA reset | ✔ | ✔ | — | — | — |
| Roles & Permissions | ✔ | — | — | — | — |
| Teams | ✔ | ✔ | ✔ | R | R |
| Projects — view | ✔ | ✔ | ✔ | R | R |
| Projects — delete/transfer | ✔ | ✔ | — | — | — |
| Analytics — view | ✔ | ✔ | ✔ | R | R |
| Analytics — export | ✔ | ✔ | — | — | — |
| AI — view | ✔ | ✔ | ✔ | R | R |
| AI — credits/quota | ✔ | ✔ | — | — | — |
| AI — keys/models | ✔ | — | — | — | — |
| Billing — view | ✔ | ✔ | ✔ | — | R |
| Billing — manage | ✔ | ✔ | — | — | — |
| Billing — refund | ✔ | — | — | — | — |
| Support — act | ✔ | ✔ | ✔ | ✔ | — |
| Support — impersonate | ✔ | ✔ | — | — | — |
| Moderation — act | ✔ | ✔ | ✔ | — | — |
| Moderation — rules/blocklists | ✔ | ✔ | — | — | — |
| System — flags/announcements | ✔ | ✔ | — | — | — |
| System — config/maintenance | ✔ | — | — | — | — |
| Audit — view | ✔ | ✔ | R | — | R |
| Audit — rollback | ✔ | — | — | — | — |
| Errors | ✔ | ✔ | R | — | R |
| Feedback | ✔ | ✔ | ✔ | ✔ | R |

---

## 6. Recommended tech stack

Chosen to pair with the existing footprint (static frontend on **Vercel**, **Cloudflare Workers**
already used for the ImageKit and email relays) and to keep V1 lean.

| Layer | Recommendation | Why |
|---|---|---|
| **Admin frontend** | Next.js (App Router) + TypeScript, Tailwind + shadcn/ui, TanStack Query + TanStack Table | Server components for fast, permission-aware pages; best-in-class data tables; matches the product's design language. |
| **Accelerator (optional)** | Refine or React-Admin | Cuts CRUD boilerplate for a 14-module panel; drop to custom pages where needed. |
| **Backend API** | NestJS (Node + TS) **or** Hono on Cloudflare Workers | NestJS if you want a batteries-included, guard-based RBAC monolith; Hono/Workers if you stay in the Cloudflare edge ecosystem you already use. |
| **Auth (admins)** | SSO via Clerk/Auth0/WorkOS + **mandatory MFA** | Don't build admin auth. Enterprise SSO + MFA out of the box; admins are provisioned via your IdP. |
| **Auth (product users)** | Clerk/Supabase Auth/Auth.js | Replaces today's localStorage accounts — the prerequisite for all of the above. |
| **Primary DB** | PostgreSQL (Supabase/Neon/RDS) + Prisma or Drizzle | Relational fits RBAC, billing, teams; typed ORM. |
| **Cache / sessions / rate-limit / queue** | Redis (Upstash) + a queue (BullMQ / Cloudflare Queues) | Sessions, rate limits, background jobs. |
| **Analytics / audit store** | Read replica for V1; ClickHouse or Postgres+partitioning for scale | Keep heavy reads off the write DB. Audit log in an append-only table/WORM bucket. |
| **Object storage** | Cloudflare R2 / S3 | Generated files, exports, template assets. |
| **Secrets** | Cloud KMS / Vault (never in DB or UI) | AI provider keys, webhook secrets. |
| **Billing** | Stripe (source of truth) + webhook sync | Never store card data. |
| **Errors** | Sentry (integrate, don't rebuild) | Module 13 is mostly a deep-link into Sentry. |
| **Infra guardrails** | Admin app on its own subdomain, IP allowlist, WAF, per-route rate limits | Reduce blast radius. |

---

## 7. UI/UX best practices

- **Tables are the workhorse.** Sticky headers, column sort, saved filters, cursor pagination, density
  toggle, keyboard row navigation, and a fast global command palette (`⌘K` → "find user by email").
- **Detail pages are tabbed,** not one long scroll (Overview / Activity / Billing / Sessions / Notes).
- **Destructive actions:** red, secondary placement, typed confirmation ("type the email to ban"),
  mandatory reason field, and a success toast that links to the audit entry. The riskiest re-prompt MFA.
- **Show provenance everywhere:** "changed by <admin> · 2h ago" inline; a History tab per resource.
- **Empty, loading, and error states** for every view; optimistic UI only for safe, reversible edits.
- **Never surface secrets:** mask keys/tokens, write-only secret fields, "set/unset" indicators.
- **Impersonation banner** is loud, fixed, and always present in that session.
- **Accessibility:** full keyboard operability, focus management in modals, WCAG-AA contrast, ARIA on
  tables/dialogs (the product already sets this bar).
- **Responsive but desktop-first:** admins work on laptops; degrade gracefully, don't over-invest in mobile.

---

## 8. Security requirements (cross-cutting)

| Requirement | Implementation |
|---|---|
| **RBAC** | Server-side permission checks on **every** endpoint; UI gating is cosmetic. No role grants a permission the grantor lacks. |
| **Least privilege** | Split high-risk permissions (delete, ban, refund, impersonate, keys) from general edit; minimize Super Admins. |
| **Audit logging** | Every mutation writes an append-only `audit_log` entry (actor, before/after, IP, UA) in the same transaction. |
| **MFA for admins** | Mandatory for all admin accounts; **step-up re-auth** for ban/delete/refund/impersonate/config. |
| **Session management** | Short-lived admin JWTs + refresh; global "revoke all sessions"; idle timeout; device/session list; separate cookie scope for impersonation. |
| **Secure impersonation** | Time-boxed, read-only default, distinct scoped token, loud banner, cannot target admins or touch billing/MFA, fully audited, user-notified. |
| **Rate limiting** | Per-admin and per-endpoint limits; stricter on write/bulk/export; blocklist integration. |
| **Sensitive-action confirmations** | Typed confirmation + reason capture + step-up MFA on destructive/financial/config actions; idempotency keys on money movements. |
| **Encryption** | TLS everywhere; encryption at rest; secrets in KMS/Vault (never DB/UI/logs); PII columns encrypted or tokenized where feasible. |
| **Compliance (GDPR / SOC 2)** | Data export & right-to-erasure flows; data-retention policies; audit-log retention ≥1 year; access reviews; PII scrubbing in logs/errors; DPA with subprocessors (Stripe, AI providers); least-privilege access reviews and change management. |

---

## 9. V1 vs V2 scope

**Ship in V1 (operational safety + revenue):**

- Dashboard (KPIs + recent activity + quick actions)
- User Management (search, profile, verify/suspend/ban/delete, password reset, MFA reset, sessions)
- Roles & Permissions (built-in roles + basic custom roles; server-enforced)
- Teams (view, members, roles, transfer)
- Projects (search, view sandboxed, archive/restore/delete)
- Billing (view, plan change, refund, cancel/reactivate, invoices) — via Stripe
- Support: **secure impersonation (read-only)**, account recovery, notes, basic tickets
- AI Management: usage, credits/quota, job monitor, failed generations, key management
- Moderation: flag queue, blocklists (IP/domain), rate-limit config
- System: feature flags, maintenance mode, announcements, email templates, webhooks
- **Audit Logs (append-only, searchable)** — non-negotiable for V1
- Error Monitoring via **Sentry integration** (embed/deep-link, don't rebuild)
- Basic Feedback inbox with status + assignment

**Defer to V2 (scale, automation, polish):**

- Custom/configurable dashboards, saved views, cohort/retention analytics, forecasting
- ABAC & just-in-time / approval-gated role grants
- Bulk user actions, saved segments, account merge, self-serve GDPR export/erase
- Write-mode impersonation with approval workflow; ticket SLAs/macros/CSAT
- ML spam scoring, auto-moderation + appeals, shared threat intel
- Config versioning/rollback, scheduled announcements, flag targeting-rule UI, template i18n
- Audit SIEM streaming + integrity hashing; anomaly detection on admin behavior
- Public roadmap/voting, changelog publishing, warehouse/BI sync

---

### Appendix — prerequisite reality check

None of this is buildable on the current HTMLStudio (client-side accounts, no server). The critical
path is: **(1)** stand up real auth (Clerk/Supabase/Auth.js) + Postgres and migrate accounts off
`localStorage`; **(2)** introduce the multi-tenant model (users ↔ teams ↔ projects) server-side;
**(3)** then layer this admin panel on top as a separate, SSO+MFA-protected deployment. Everything
above is designed to slot onto that foundation without rework.
