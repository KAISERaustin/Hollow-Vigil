# Private backups and Community

Current implementation: September 7, 2026. The shared menus are documented in [UI_MENU_TREE.md](UI_MENU_TREE.md). Older manual world and Campaign-count APIs remain for installed-client compatibility; their historical behavior is not the current menu flow.

Hollow Vigil works offline. Local saving and gameplay do not wait for cloud requests. Signed-in devices automatically back up complete saved games and the private My builds library. Community publication is a separate, explicit action.

## Project and ownership

- Project: Hollow Vigil (`sjjohzftzshgceamffhx`).
- Dashboard: https://supabase.com/dashboard/project/sjjohzftzshgceamffhx
- Public client configuration: `supabase/client.cfg`; it contains the project URL and publishable key, never a service-role key.
- Every private row belongs to `auth.uid()`. Owner RLS and explicit Data API grants apply to tables and invoker functions. Anonymous clients cannot list or restore private data.
- Community is intentionally publicly readable. Publishing requires authentication and a player name.

| Store | Current purpose |
| --- | --- |
| `private_games` | Three Campaign and three Infinite snapshots per account, keyed by game type and slot, with content hash and revision |
| `private_builds` | Immutable, deduplicated reusable builds belonging to one account |
| `public_builds` | Separately published reusable builds with title, description, author and publication time |
| `player_profiles` | Player display name; authentication remains in Supabase Auth |
| Legacy world tables and `campaign_backups` | Compatibility with earlier clients; not used by the new private backup service |

The new game API accepts complete snapshot objects with identity and mode checks and a 32 MiB limit. The receiving client validates the complete game through its persistence owner before restoring. Reusable builds have their own checksummed envelope, selected-content schema, registered-type validation and 16 MiB limit. The database checks their public envelope and metadata; it does not replace the client's gameplay validation.

## Complete games and reusable content

A Campaign snapshot contains its identity, Creative/Survival style, completion, independently edited levels and loadouts, and its unfinished mission checkpoint. Continuing or restoring a battle recreates the current wave from its starting resources, tower state, equipment, rules, health and random state. Mid-wave rewards are not combined with a restarted enemy wave.

An Infinite snapshot contains the saved world, progression, custom rules, placed towers, gear, encounters, economy and the other fields in its validated local save. Reconstruction still uses installed content definitions. Ordinary live enemy/projectile arrays are not serialized. Complete private snapshots retain local save fields, unlike the older projection that deliberately omitted camera and preferences.

A reusable build contains only its selected groups and required placement dependencies. Omitted categories start from original defaults. Builds do not carry account credentials, cloud identity, earned Campaign unlocks or device preferences. Stats can be reused between game types; authored waves and map layouts remain specific to their game type. Source and destination level choices are explicit. Saving or downloading a build never uses a playable slot.

Stable type keys refer to the hierarchy in `scripts/content/`. Add a content definition to its catalog and the shared build checklist discovers it through its registered group. No per-enemy or per-tower database enum is needed. New behavior belongs in reusable nodes or attachable components; a new persistent field still needs appropriate client validation and format evolution. See [NODE_SYSTEM.md](NODE_SYSTEM.md).

## Account and player flow

Settings → Account supports an email code or the project's sign-in link, player-name editing and sign-out. The client validates eight ASCII digits or a link to the exact project HTTPS endpoint. The rotating refresh credential is stored separately from saves in the device's account-session file. Startup verifies it with Auth before restoring account identity. Sign-out removes the saved credential and invalidates in-flight callbacks. Credentials never enter game backups or reusable builds.

Backups is the same page from Game home or the held gameplay Menu:

1. Account status distinguishes local progress, pending private backup, successful protection and a conflict that needs a choice.
2. **Back up now** covers all six saved-game slots and My builds.
3. Choose a cloud or local recovery copy and one of the matching game type's three destinations.
4. An empty destination still requires confirmation. A different game is named before replacement. Different versions of the same game show progress, time, resources, towers, gear and custom-rule information, then offer Keep this device's version or Use cloud version.
5. Restoring returns to Saved games. Restoring over the held active slot first asks to exit that session. Keeping the device version never performs a restore afterward.

Replacing a local game retains a named recovery copy. Recovery files are browsable through Backups without adding active slots. An unreadable occupied slot is not treated as empty and cannot be silently replaced.

## Automatic sync and conflict handling

`scripts/cloud/private_backups.gd` owns this service independently of legacy world uploads:

- Local changes request a three-second debounce. Signed-in play also checks every 60 seconds; a new account schedules a check after one second.
- Network failures preserve local progress and retry after 15 seconds, doubling to a five-minute maximum. Busy and account-generation guards prevent overlapping requests or applying a response after sign-out/account change.
- Each account keeps acknowledged hashes and revisions separately. Uploads compare the expected server revision. The server serializes first inserts and updates; repeated identical snapshots are idempotent.
- A differing remote revision cannot silently overwrite or be overwritten. Even an unchanged local copy detects a newer remote revision when the service lists backups.
- Keep this device's version submits against the revision the player reviewed. Another device changing it again produces another conflict.
- A fresh device lists cloud games for explicit restore; it does not automatically fill local slots. Private My builds entries are automatically recovered and merged by content hash, including when a local entry is missing but its old acknowledgement remains.
- Library requests page one entry at a time so a maximum-size build fits the transport limit. No private-sync path calls a public publishing function.

The server stores the current version of each private slot. Local recovery copies preserve replaced games; this is not an unlimited server history browser. Complete backup is a recovery mechanism, not an authoritative multiplayer economy.

## Community publishing

The shared Save build form saves a private copy before attempting **Share to Community**. Account operations return to the prepared form with its selections intact. A failed share exposes Retry and retains the private copy. The exact prepared payload stays queued; reconnecting alone does not publish it. If the player changes accounts before explicitly retrying, publication is queued for the currently signed-in player and the previous account's queue is left intact.

Community uses `list_build_library`, `read_public_build` and `publish_reusable_build`. The menu shows names, descriptions, contents, compatibility and author information. Raw JSON, file paths, codes and internal identifiers are not exposed as player exchange controls.

## Migrations and verification

The following migrations were applied to the project and their filenames match the live migration versions:

- `20260907182045_unified_games_and_builds.sql`: private game/library tables and APIs, v2 Community publishing and listing, grants and owner policies.
- `20260907183330_unified_contract_guards.sql`: explicit null rejection in reusable-build metadata and revision comparisons, plus friendly content labels.

Earlier migrations include manually applied history. Inspect local and remote history before using a blanket `db push`; the new migrations do not reconcile every older discrepancy.

Run from the repository:

```powershell
./launch.ps1 -UnifiedTests
./launch.ps1 -Check
```

`-UnifiedTests` isolates user data and runs:

- `tests/unified_persistence_runner.gd`: all nonempty content-group combinations, selected registered types, cross-game stat transfer, defaults, dependency failures, six-slot isolation, complete Campaign checkpoints and recovery.
- `tests/private_backups_runner.gd`: an asynchronous transport fixture for all six slots, complete customized Campaigns, second-device library recovery, offline retry, conflicts, account changes and absence of automatic publication.
- `tests/rendered/unified_menu_runner.gd`: native menu workflows at 360×640, 390×844 and 540×960, including form preservation, replacement/restore choices and matching HUD controls.

Execute `tests/unified_cloud_contracts.sql` through the project SQL connection. It creates synthetic identities inside one transaction, uses real authenticated roles and JWT claims, verifies all six complete snapshots, idempotency, stale revisions, null/fourth-slot rejection, private-library recovery, Community publishing and owner isolation, then rolls back every fixture. A successful result is `Unified cloud contracts passed; all fixtures rolled back`.

The legacy `supabase/tests/cloud_contract.sql`, codec/service runners and `tools/cloud_live_runner.gd` exercise the older world API. They remain useful compatibility checks but are not evidence for complete Campaign restore or the new automatic service.

On September 7 the new live SQL contracts passed and Security Advisor returned no findings. User-authorized cleanup removed two legacy world backups, one legacy Campaign backup and 31 local backup files; active games and the existing public build were preserved. No migration of those test backups was performed.

Native desktop rendering and simulated second-device services do not establish installed-device acceptance. Email delivery, SMTP configuration, a physical second-device restore and a new iOS/Android release were not exercised as part of this redesign. Historical Auth setup and cloud investigations remain in `CLOUD_ACCEPTANCE_2026-09-06.md` and Git history; their quota and dashboard observations are dated.
