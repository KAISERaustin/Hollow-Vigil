# Campaign cloud audit — September 9, 2026

Target verified from both the configured client and live Supabase inventory: Hollow Vigil, `sjjohzftzshgceamffhx`.

## Live table decisions

| Tables | Decision and evidence |
| --- | --- |
| `worlds`, `save_revisions`, `progress`, `checkpoints`, `regions`, `relics`, `towers`, `unlocks`, `encounters`, `production`, `preferences`, `world_rules` | Removed. Legacy normalized Infinite-world save graph; current game backs up Campaign slot documents. Removed its `publish_save`, `read_save`, `list_saves` APIs and private publishing function. |
| `campaign_backups` | Removed. Stored only completed-level counts, not authored Campaign rules or loadouts. Removed its RPCs and obsolete client node/test. |
| `private_games` | Kept for three account-private Campaign slots. Removed Infinite acceptance and obsolete 20-level limit; added document validation. Preserves nested authored level/wave/entity/loadout values and revision conflict handling. |
| `private_builds` | Kept for immutable personal Campaign build documents. Validates the envelope, payload checksum, content hash, Campaign scope and nested content at the table boundary. |
| `deleted_private_builds` | Kept. Account-private tombstones prevent another device from automatically restoring a deliberately deleted library build. |
| `public_builds` | Kept for explicit Community sharing. Enforces the same Campaign contract, matching title/description, and author ownership. Added the missing Auth foreign key so deleted accounts cannot leave orphaned publications. |
| `player_profiles` | Kept for account metadata. The live Auth trigger still maintains this account-owned projection; trigger insertion was verified with temporary users. |
| `bug_reports`, `change_log` | Kept at the user's explicit request, including 1 existing report and 46 change-log records. |

No Edge Functions were deployed. Supabase-managed Auth, Storage, Realtime and extension schemas were preserved. There were no Storage objects to clean up.

## Reset and access

The user explicitly authorized deleting all test accounts while preserving registration/sign-in. Removed six users, 22 sessions, refresh tokens and test game/library data. Final exact counts: zero Auth users, sessions, profiles, private games, private builds, deletion tombstones and public builds. Seven application tables remain, all with RLS enabled. Profile/Auth infrastructure remains available for new accounts.

The public library remains readable to other players and anonymous browsers. Private backups and library entries remain owner-only. Direct table writes must satisfy the same Campaign constraints as RPC calls. Display-name metadata is presentation only; ownership uses `auth.uid()` and Auth foreign keys.

## Contract and tests

The old cloud validator accepted Infinite builds, stopped at level index 19, required 20-level playthroughs and rejected `defeat_gold`. Current validation uses the shared content catalog, supports all 30 levels, selected levels 0–29, added/removed waves, entity and attachable attribute values, entrance/timing bounds and per-group gold. It preserves whole envelopes without flattening or modifying payload text. Client validation additionally checks gameplay-specific composition and legal tower placement.

Game-generated fixtures verified that all 30 levels retain distinct starting gold, enemy health, tower damage, wave rewards and per-group gold after export/import. Live `supabase/tests/campaign_cloud_acceptance.sql` passed upload/readback equality, final-level entity settings, Community browsing, private isolation across two users, anonymous read-only behavior, retry idempotency, stale revision conflicts, and rejection of Infinite data, corrupt checksums, negative rewards and invalid entrances. All temporary test accounts/data were rolled back.

`./launch.ps1 -UnifiedTests`: 87 checks, zero failures (Campaign-only 22, Campaign private backups 17, account session 34, bug reports 14). Physical phone sign-in and email delivery were not exercised.

Supabase security advisor: no findings. Performance advisor reported only informational items: unused indexes on the newly emptied public library and the change-log feed, and fixed Auth connection allocation. Those indexes support retained access paths and were preserved. See [index advisory](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index) and [Auth scaling guidance](https://supabase.com/docs/guides/deployment/going-into-prod).

Validation follows Supabase's [JSON Schema extension guidance](https://supabase.com/docs/guides/database/extensions/pg_jsonschema). Reset handling follows [user management guidance](https://supabase.com/docs/guides/auth/managing-user-data); sessions were removed as well as users. Migration history was retained and local filenames aligned with the applied remote versions.
