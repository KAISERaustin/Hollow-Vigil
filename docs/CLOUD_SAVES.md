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

Open Settings → Cloud saves. Request an email and enter its eight-digit code within 15 minutes. Alternatively, copy its sign-in link without opening it and paste it into the same field. Only verification links for this project's exact HTTPS endpoint are accepted; the game exchanges the hash directly with Supabase. Codes are bound to the requested email, preserve leading zeros, and reject non-ASCII digits. The input is masked. Tokens and email are kept in memory only, so restarting the game requires sign-in again. No credentials are written into saves or the repository.

Supabase's built-in mail service restricts recipients to organization/team email addresses, even on Pro. This supports initial owner-device testing. Public distribution still requires configuring an email sender or another Auth provider. Both the Confirm sign up and Magic link or OTP templates now use `supabase/templates/sign-in.html` with subject `Your Hollow Vigil sign-in code`; the retained link supports older installed builds. No custom SMTP provider has been configured.

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

After the Pro upgrade on 2026-09-06, Security Advisor reported no findings. Schema was applied through the dashboard; the CLI migration history has not been reconciled, so do not blindly run `db push` against this existing project.

## Pro configuration

The Supabase connector was reconnected and verified with the Hollow Vigil project list, organization plan (`pro`), and a SQL query confirming all twelve public tables have RLS. Future tools must target `sjjohzftzshgceamffhx`; a connection exposing another project is not a reason to change `client.cfg`.

Verified dashboard settings:

- Leaked-password protection enabled (Pro), plus reauthentication for password changes. The game itself remains passwordless.
- Session lifetime: 720 hours (30 days); inactivity timeout: 168 hours (7 days). Both limits are Pro features and are enforced on refresh. Single-session enforcement remains off to support cross-device saves. Access tokens retain the recommended 3,600-second lifetime and refresh-token replay detection remains enabled.
- Email codes/links expire after 900 seconds; code length is eight digits. Branded templates and code entry improve the sign-in flow but OTP itself does not require Pro.
- The game clears expired credentials and shows sign-in again when refresh is rejected, while retaining its durable outbox. Network failures and rate limits preserve the session for retry. Signing back into the same account recovers the queued mutation.
- Daily database backups and seven-day log retention are included automatically in Pro. The spend cap remains enabled. No additional compute, branch, PITR, custom domain or log-drain subscription was purchased.

Validation: 27 service checks and 30 codec checks passed. The live rollback-only SQL contract passed through the repaired connector. The isolated rendered panel check (`tests/cloud_panel_runner.gd`) passed at 390 × 844; the full-app cloud UI runner stalled reading an existing imported audio resource and was stopped, so full-app rendering remains unverified for this change. Email templates were previewed and saved in the dashboard; delivery and a successful real email-code exchange have not been exercised in this change. Existing installed builds need a new game release to expose code entry; their link sign-in remains supported.

### Recovery and operations

Use [Scheduled backups](https://supabase.com/dashboard/project/sjjohzftzshgceamffhx/database/backups/scheduled) to inspect the most recent successful backup. At verification, the only available physical backup was **2026-09-06 07:18:19 UTC**, before the cloud-save schema was installed. Wait for a newer scheduled backup before relying on it to recover this schema and its data. Seven-day retention is a rolling window, not seven backups immediately after upgrading.

For an individual device issue, use the game's restore/conflict controls and local `.before-cloud-*.save` recovery files first. A database restore affects every player and loses changes after the selected backup; it is an incident operation, not an individual player's undo button. Before a database restore, preserve current data and pause cloud writes, identify the backup timestamp and affected players, and arrange downtime. After restoration, confirm project health, run the SQL contract, and test authenticated save listing and restore before resuming cloud writes. Reconcile device outboxes explicitly: restoring the database also rolls back revision counters, so do not assume devices will resume transparently. No destructive restore drill was performed here.

Backups contain database records, not Storage file contents. The game currently keeps its assets in the installed build. If cloud-hosted assets are added, provide an independent object backup process.

Use [Logs](https://supabase.com/dashboard/project/sjjohzftzshgceamffhx/logs) for the included seven-day history and [Security Advisor](https://supabase.com/dashboard/project/sjjohzftzshgceamffhx/advisors/security) after schema/auth changes. SQL contract tests intentionally cause rejected operations; distinguish these from player-facing failures. Check [organization usage](https://supabase.com/dashboard/org/gehcbpsnzylmdwlkmwud/usage) before increasing resource limits.

References: [Pro plan](https://supabase.com/pricing), [session controls](https://supabase.com/docs/guides/auth/sessions), [password protection](https://supabase.com/docs/guides/auth/password-security), [email codes](https://supabase.com/docs/guides/auth/auth-email-passwordless), [database backups](https://supabase.com/docs/guides/platform/backups).


## Save/reload sync fix (2026-09-06)

Godot loads JSON numbers as floats. The original RPC cast JSON text directly to
Postgres integer types, rejecting values such as `42.0`, `2.0`, and `24.0` with
`22P02`. This affected normal road bends as well as reloaded worlds and durable
outboxes. The `accept_integral_json_numbers` migration normalizes only declared
integer fields, rejects fractions and numeric strings, and keeps ownership,
revision guards, transaction boundaries, and row constraints intact. The codec
now emits explicit integers and restores road bends as floats for local validation.

The deployed migration version is `20260906143446`. Earlier migrations were applied
manually; their pre-existing history discrepancy still needs reconciliation before
using `db push` on this project.

Regression commands:

```sh
Godot --headless --path . --script tools/cloud_payload_fixtures.gd
Godot --headless --path . --script tests/cloud_codec_runner.gd
Godot --headless --path . --script tests/cloud_service_runner.gd
```

The fixture generator writes seven real save/reload projections covering a new
world, all four active bosses, a castle encounter, equipped relics, an electric
tower, production history, and sound preferences. Live SQL verification runs them
inside a rolled-back transaction under an authenticated test identity and forces
deferred foreign-key checks before comparing normalized records.

For an opt-in live client test, set `HOLLOW_CLOUD_EMAIL`, run
`Godot --headless --path . --script tools/cloud_live_runner.gd -- --send-code`, then
set `HOLLOW_CLOUD_CODE` to the fresh code and run the same command without
`-- --send-code`. Each successful run creates one separate test world (seed
424242), never modifies existing worlds, and clears its disposable local files.
Credentials remain in memory. The test covers real HTTP authentication, upload,
restore, legacy float-valued outboxes, retries, conflicts, token refresh, network
failure/recovery, minute sync, and sign-out.

Email delivery is separately constrained by the built-in Supabase mail quota.
`over_email_send_rate_limit` now has a specific user-facing message; repeated sync
failures are no longer confused with this email-provider error. A server-generated
OTP can exercise the actual client/Auth/RPC flow without sending email, but is not
evidence that email delivery is working. Public email sign-in still requires a
custom SMTP provider; no sender credentials or subscription were configured here.


Current verification: 37 codec checks, 32 service checks, 20 live Godot HTTPS
checks, the rollback-only SQL contract, seven generated gameplay fixtures, and
30,451 gameplay regression checks passed. The full cloud screen and masked panel
also rendered successfully at 390 × 844. Security Advisor returned no findings.
The live run used the existing owner account with an admin-generated OTP because
normal email requests returned HTTP 429 `over_email_send_rate_limit`. The two
worlds created by this debugging session were removed after verification; the
pre-existing cloud world and player saves were preserved. No physical second-device
or iOS release test was performed. Email delivery under the exhausted quota remains
an external limitation, so this is not a claim of production-ready public sign-in.
