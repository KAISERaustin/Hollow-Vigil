# Campaign saves and account services

The local game supports three Campaign slots shared by Creative and Survival. Each snapshot contains mode, identity, completed levels, map selection, equipment and custom level rules. The current game starts unfinished levels fresh on reentry; older checkpoint payloads remain validated for compatibility. Local writes validate and checksum data, preserve recovery candidates, and reject incompatible content.

`private_backups.gd` supports explicit Campaign uploads and recovery through the existing account-private APIs. Automatic backups are removed: there is no frame timer, save queue, sign-in trigger, periodic scan or retry loop. In **My builds → Details**, **Upload build** sends only the selected build to private cloud storage. **Backups → Upload to cloud** explicitly uploads all saved slots and builds. **Recover My builds** only downloads private library entries and refreshes remote saved-game listings; it never uploads. Restoring or keeping the device version never starts another upload. Failed operations require another explicit action. It uploads only Campaign slots, filters remote game listings to Campaign, validates restored snapshots with `CampaignSlots.valid`, and skips incompatible library entries. Cloud revision conflicts wait for a reviewed player choice. Replaced local games remain available as recovery copies. Account changes invalidate in-flight requests.

The current backend provides `put_private_game`, `list_private_games`, `read_private_game`, `delete_private_game`, private-library synchronization, and Community build APIs. September 9 migrations removed obsolete Infinite storage and completion-only backups, reset authorized test accounts, and enforce Campaign-only documents in table CHECK constraints as well as RPCs. The database now accepts all 48 levels and per-group defeat gold. See `CLOUD_CAMPAIGN_AUDIT.md` for the live inventory and verification.

Community and private library uploads use `hollow-vigil-reusable-build-v2` with `game_type = campaign`. Older local Campaign/stat documents are converted through `VigilSaveSlots.reusable_entry()` before upload; local originals are preserved. A whole-Campaign build includes exactly 48 levels; a level build contains its selected level. Each entry retains selected entity rules, optional starting resources and tower equipment/layout, and each wave's timing, counts, composition, entrance lanes, rules and rewards. Signed payload text and checksum are stored without rewriting. Public builds exclude account identity, completion and live combat state. Private slot backups separately preserve Campaign identity, progression, equipment and authored overrides. Current cloud snapshots require empty combat checkpoints, matching the game's fresh-attempt behavior; older local checkpoint files remain locally readable.

Sign-in credentials use the dedicated account session store. Sound preferences use `vigil-preferences.cfg`, independently of playable slots. Private saving works offline. Community publication occurs only after an explicit Share to Community or Retry action; private uploads never publish. Library status text does not scan or decode saved builds.

Validate local persistence and synthetic backup transport with `./launch.ps1 -UnifiedTests`. The live SQL acceptance test verifies RPC behavior under owner, other-account and anonymous database roles and rolls back its data. Physical device sign-in and the HTTP authentication flow remain separate checks.

## Manual-cloud validation — September 17, 2026

- Private-cloud regression: 34 checks passed, including no background scans or
  requests, explicit selected-build upload, no retries, download-only recovery,
  restore/keep-local behavior and account changes.
- Rendered Campaign regression: 106 checks passed at 360x640, 390x844 and 540x960;
  real kills, wave clears, victory and focus-save callbacks did not upload.
  Explicit touch uploads and retries worked; the screens were visually inspected.
- Account-session regression: 35 checks passed. Campaign integration: 20 checks
  passed, with a shutdown warning for two leaked ObjectDB instances.
- Structure and whitespace checks passed. Cloud transport was simulated; these
  results do not establish live-server or physical Android acceptance. No store
  release was produced.

The rendered and Campaign integration checks used an isolated source copy after
local resource reads stalled in the shared checkout. The isolated copy included
the working changes and the same imported assets.
