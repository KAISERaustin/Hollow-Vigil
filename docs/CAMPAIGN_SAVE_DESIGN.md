# Campaign and Infinite backups

Implemented September 6, 2026. This replaces the earlier automatic-sync proposal.

## Player contract

The game is offline first. Three independent Infinite slots and one Campaign progress record save on the device. Only an explicit Upload action sends a selected record to Supabase. Signing in, playing, winning, switching modes, restoring, restarting, reconnecting and changing preferences never upload progress. Failed uploads remain available for an explicit retry; there is no timer, automatic retry or background publication.

Campaign records only the number of sequential levels completed (0–30). Completing level 7 unlocks level 8; leaving level 8 unfinished means starting level 8 from the beginning. Replaying an earlier level cannot increase the count. Medals, towers, gold, health, wave state and active mission checkpoints are not saved locally or uploaded.

## Ownership and files

- `scripts/campaign/progress.gd` owns the version-2 completed-level record and reuses `VigilSaveStore` for checksummed writes, temporary-file verification, backup rotation and newest-valid-sequence recovery.
- The application owns Campaign progress independently of the visible screen and active Infinite slot.
- `scripts/cloud/campaign_backup.gd` is a composed service Node using the existing account and HTTP service. Its adjacent `.cloud-backup` file holds account binding, revision and any explicitly attempted pending mutation.
- Each Infinite slot retains its existing save, world UUID and `.cloud-outbox`. Uploading an inactive slot reads its committed snapshot without running the simulation, crediting offline income or advancing its accounting timestamp.
- The shared Account & backups screen is reachable from the slot picker, Campaign and Infinite settings, including when there is no Infinite world.

## Manual upload and restore

Each explicit upload persists an immutable snapshot, expected server revision and mutation UUID before sending it. An explicit retry resends that same attempt; later gameplay remains local. The player can upload again after acknowledgement to back up later progress. No request is scheduled for later delivery.

Server revision checks prevent silent replacement by another device. Conflicts require an explicit replacement or restore choice. Balances and Campaign counts are replaced rather than combined. A second competing upload can cause another conflict even after a choice.

Campaign restore re-reads the remote record, validates it, preserves existing local candidates (including corrupt bytes) in recovery files and writes a newer local sequence. It discards any active mission and opens the map. Restoring Campaign cannot replace Infinite progress. Infinite restore targets the selected slot and retains its existing recovery behavior.

## Backend

`public.campaign_backups` contains at most one row per authenticated account: player UUID, format, catalog version, completed-level count, revision, latest mutation UUID and server update time. A new account has no Campaign row until it explicitly uploads. Owner-only RLS allows reading; direct client writes and anonymous access are denied. `read_campaign_backup` reads the count, and `publish_campaign_backup` validates the exact payload and applies the revision-checked transaction. Latest-mutation retries are idempotent.

Migration `20260906192637_manual_campaign_backups.sql` is deployed and matches its live history entry. Existing historical migration drift is unrelated; do not blindly run a blanket `db push`.

Infinite retains its existing normalized tables and per-world API. The UI exposes exactly three local upload choices. Historical cloud worlds remain available for restore under the existing ten-world account limit; this change does not delete old backups or impose a new server slot mapping. Cloud revisions protect concurrent writes and are not a selectable backup history.

## Legacy migration

Version-1 Campaign medals convert to the contiguous completed-level count. The old active checkpoint and medal scores are discarded. The selected original file is archived before the converted record is written. Conversion is idempotent, and unreadable candidates remain protected from ordinary writes. The original twenty level identities remain fixed. Castle Ruin and Mourning Orchard append levels 21–30, so a completed original campaign unlocks level 21. Twenty-medal saves remain readable; changing existing progression order would require an explicit format/content migration.

## Verification

- `tests/campaign_runner.gd`: completed-level progression, unfinished-level restart, replay rules, legacy migration and recovery.
- `tests/campaign_backup_runner.gd`: manual upload/retry, no automatic writes, conflicts, account changes and restore.
- `tests/manual_backups_runner.gd`: inactive Infinite snapshot and slot isolation.
- `tests/cloud_service_runner.gd` and `tests/public_builds_runner.gd`: no timer-triggered upload or retry, durable explicit attempts and account isolation.
- `tests/rendered/campaign_runner.gd` and `tests/rendered/mobile_scroll_runner.gd`: native phone-sized Campaign and explicit backup controls.
- `supabase/tests/campaign_backups_contract.sql`: rollback-only server validation, owner isolation, direct-write denial, idempotent retries and revision conflicts.

Database contract tests use synthetic records and roll back. This change does not authorize uploading a real player's progress for QA. Physical-device acceptance and a new installed release are separate from desktop and database checks. Older installed versions retain their old automatic-sync behavior until updated.
