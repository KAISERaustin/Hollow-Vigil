# Cloud saves

Hollow Vigil remains playable without an account or network connection. Local saving and offline rewards run before and independently of cloud requests. Supabase is a private cross-device backup, not an authoritative multiplayer economy.

## Project

- Organization: Hollow Vigil (`gehcbpsnzylmdwlkmwud`)
- Project: Hollow Vigil (`sjjohzftzshgceamffhx`), Ohio (`us-east-2`)
- Dashboard: https://supabase.com/dashboard/project/sjjohzftzshgceamffhx
- Public client configuration: `supabase/client.cfg`. It contains only the public URL and publishable key; never add a secret/service-role key.
- All twelve public tables have RLS and owner-only SELECT policies. Anonymous users have no access. Authenticated clients cannot write tables directly.

## Identity and data boundary

| Table | Identity and stored values |
| --- | --- |
| `player_profiles` | Auth user UUID; optional display name. Email and authentication remain in Supabase Auth. |
| `worlds` | Random world UUID, owner/player UUID, immutable seed, save version, creation timestamp. |
| `save_revisions` | UUID, world UUID, monotonically increasing revision, most recent mutation UUID, server timestamp. |
| `progress` | UUID, world UUID, gold/reserve, lifetime counters, next local tower ID, automation/onboarding flags. |
| `checkpoints` | UUID, world UUID, accounted-through timestamp, active seconds. |
| `regions` | UUID, world UUID, local coordinate, parent region UUID, road reconstruction fields, traffic, production sample duration. |
| `unlocks` | UUID, world UUID, region UUID, unlocked enemy kind. |
| `towers` | UUID, world UUID, local tower key, region UUID, type/socket, level/branch, earnings, targeting, rebuilding time, equipped relic UUID. |
| `relics` | UUID, world UUID, source coordinate, relic kind. |
| `encounters` | UUID, world UUID, source coordinate, castle flag, kind/status, compact active boss checkpoint. Road paths are rebuilt locally. |
| `production` | UUID, world UUID, region/tower UUIDs, demonstrated earnings needed for offline rewards. |
| `preferences` | UUID, world UUID, optional sound volumes and mute setting. No row unless opted in. |

World UUIDs are random. Child UUIDs are deterministic UUIDv8 identifiers derived from the world UUID, entity category and local key. They identify instances, not values: changing a tower's level or gold never changes its identity. Composite foreign keys prevent cross-world links. Code/definitions remain in the installed game; kind keys refer to those definitions.

The encoder constructs every field explicitly. No arbitrary JSON save blob is stored. Server functions reject unknown fields, including nested record fields. No source files, artwork/audio/fonts, camera position, graphics settings, developer controls, debug output, caches, projectile/enemy arrays, contact lists, analytics or device identifiers are uploaded. Active developer balance overrides block uploads; the backend does not certify that previously earned money was legitimate.

## Adding game content

Use permanent lowercase type keys (letters, numbers, underscore, dot, colon or dash, up to 128 characters). Add towers, enemies, boss types, relics, specializations, target modes or biome definitions to the game's local catalogs. The database accepts new keys without editing database enums, adding one table per type, or uploading a balance catalog. Enemy unlocks are rows in `unlocks`; ordinary active enemies are transient and are not uploaded.

Never reuse a retired type key for a different kind of content. Renaming a display name is safe; renaming a type key requires a save migration in the game. An older game build must reject a save containing unknown content rather than silently drop it. A new persistent mechanic needing genuinely new fields still requires an additive schema/codec migration and a cloud format compatibility check; new content using existing fields does not.

## Player flow

Open Settings → Cloud saves. Email a sign-in link, copy the link from the email without opening it, and paste it into the game. Only verification links for this project's exact HTTPS endpoint are accepted; the game exchanges the hash directly with Supabase. The input is masked. Tokens and email are kept in memory only, so restarting the game requires sign-in again. No credentials are written into saves or the repository.

Supabase's default free mail service restricts recipients to organization/team email addresses. This supports initial owner-device testing. Public distribution requires configuring an email sender or another Auth provider; no paid service has been enabled. Default templates use links, so custom templates/Pro are unnecessary for this initial flow.

On a new device, select a saved world and confirm restore. The previous local save is archived before the replacement is written. Alternatively, explicitly choose to back up the local world as a separate world (up to ten per account). Resetting local progress creates a separate, initially unlinked world; it does not delete existing cloud worlds.

## Sync and recovery

- After explicit backup/restore, sync runs every 60 seconds while signed in. Requests are asynchronous and time out after 15 seconds. Local saves continue every ten seconds and at normal gameplay checkpoints.
- A durable local outbox contains the allowlisted snapshot and mutation ID. A retry reuses that exact snapshot and ID, even if play continued meanwhile. A successful response advances the base revision without replacing newer local gameplay.
- The database locks the world and compares the expected revision. A save updates all related records in one transaction. Failed constraints roll back the whole update. Repeated mutations do not advance the revision or add rewards.
- Concurrent offline sessions produce a conflict. Automatic upload stops until the player chooses local or cloud progress. Choosing local still compares against the observed server revision; a new competing save causes another conflict.
- Balances are replaced, never added across saves. The accounting timestamp cannot move backwards on the server. Local offline rewards retain the existing seven-day cap and once-per-watermark behavior. This is replay-safe backup, not protection against deliberately edited client saves or clocks.
- Outbox: adjacent to the local save, with `.cloud-outbox` suffix. Recovery copies: `.before-cloud-<UUID>.save`. Never delete `.runtime` or user data wholesale.
- Sign-out stops uploads and drops in-memory credentials; local progress remains available.

## Deployment and verification

Schema changes are recorded in `supabase/migrations/`. The initial schema and functions were applied through the project SQL editor. `supabase/tests/cloud_contract.sql` runs rollback-only synthetic fixtures under real database roles to check isolation, mutation idempotency, stale revisions, allowlist rejection, constraint rollback, direct-write denial and monotonic reward accounting.

Local checks:

```sh
Godot --headless --path . --script tests/cloud_codec_runner.gd
Godot --headless --path . --script tests/cloud_service_runner.gd
Godot --path . --script tests/cloud_ui_runner.gd
```

The first two cover the allowlist, entity references, active bosses/castles, relics, offline outbox, retries and conflicts. Mock transport checks do not replace a live Auth/upload/second-device restore test. The rendered check uses disposable progress. Android exports require Internet permission; every preset includes public client configuration and excludes migrations/tests.

Verified on 2026-09-06: 30 codec checks, 17 service checks, and 30,451 existing regression checks passed. The live SQL contract passed again after the production-duration migration. Live HTTPS Auth, upload/readback, idempotent retries, stale revisions, and previously unknown tower/enemy keys passed; this left a separate test world with seed `424242` in the owner's account. This was API readback with a fresh request, not a second physical device test. The cloud screen was rendered at 390 × 844.

Security Advisor reported zero errors and one warning: leaked password protection disabled. Sign-in here uses email links. No paid plan or email provider was enabled. Schema was applied through the dashboard; the CLI migration history has not been reconciled, so do not blindly run `db push` against this existing project.
