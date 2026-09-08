# Verification

The app supports fixed upright portrait on iOS and Android. Run layout and input checks at portrait sizes only (normally 360x640, 390x844 and 540x960); do not add sideways or upside-down app viewport cases. Wide artwork contact sheets and world-coordinate tests are separate from device orientation. For native release acceptance, verify Android's portrait activity manifest and iOS's portrait-only iPhone/iPad orientation arrays, then confirm turning each phone leaves the app upright. See `AGENTS.md` for the persistent platform contract.

Use the root `launch.ps1` commands documented in the README. `-Check` runs headless, full rendered UI, GPU terrain and artwork checks sequentially. The runner prepares imports, checks script compilation, isolates test saves under `.runtime/tests`, and fails on script/engine errors. Each automated test entry point has a timeout for interrupted or failed coroutines.

`./launch.ps1 -StyleTests` checks sixteen UI screens, including tower information, Developer Controls, targeting, and relocation, at 540×960, 360×640, and 390×844 with the standard text size. It verifies viewport containment and reachable close/confirmation controls and captures `artifacts/style-*.png`. It is also included in `-Check`. Tower action targets are 48 map units at baseline zoom; their size and offsets scale with their towers, including at screen edges. Rendered smoke checks cover mouse and touch at four zooms and three viewport sizes.

## Coverage

### Unified menus, reusable builds and private backups

`./launch.ps1 -UnifiedTests` runs the complete redesign checks, also included in `-Check`:

- `unified_persistence_runner.gd`: all 255 Infinite and 1,023 Campaign nonempty group selections, individual registered enemy/boss/tower types, omitted defaults, cross-game and level scope, placement/wave dependencies, exactly three slots per game type, complete wave-start recovery and unreadable/replaced saves.
- `private_backups_runner.gd`: asynchronous transport checks for all six games and My builds, complete custom rules/towers/gear/checkpoints, second-device recovery, offline retries, stale revisions, explicit local/cloud choices and account-change guards. It verifies that automatic private backup never publishes to Community.
- `rendered/unified_menu_runner.gd`: actual mouse events through both game types at 360×640, 390×844 and 540×960. Covers home, saved games, new-game review and replacement, private/Community libraries and pagination, save/share and account return, failed-share Retry, draft Apply/Cancel, held Resume versus saved Continue, Survival locks, Backups and recovery confirmation. Screenshots use `artifacts/unified-*.png`.
- `rendered/recovery_menu_runner.gd`: the local Recovery copies browser at the same three sizes in both game types. Opens a recovery card, confirms or cancels empty-slot restore and named replacement, preserves other slots, verifies the replaced game remains recoverable, and blocks restoring over the held active game. Also activates Recover My builds against the account transport fixture.

`./launch.ps1 -MobileTests` also runs that workflow through native touch events and dropdown interaction via `rendered/mobile_playthrough_runner.gd`, alongside dedicated navigation, equipment and upgrade checks. These are desktop event simulations, not installed-phone acceptance.

`unified_cloud_contracts.sql` is a live, rollback-only database check. Run it through the Hollow Vigil project SQL connection. It uses synthetic users and real authenticated roles to verify complete snapshots, six-slot limits, idempotent retries, conflicts, library and Community APIs, and private-account isolation. All fixtures are rolled back; no real account data is used. The generated client payloads are available in the ignored `artifacts/unified-cloud-fixtures.json` after the persistence runner.

### Gameplay and shared components

- `content_node_runner.gd` / `unit/content_node_checks.gd`: content inheritance, subtype overrides, immutable catalogs, duplicate registration guards, fresh instance state, placement/equipment rules, pooled enemies, boss defenses, gear counters and campaign wave order. Included in the main headless suite. See `docs/NODE_SYSTEM.md` for the extension guide.

- `unit/enemy_checks.gd`: Lantern Keeper attunement pricing and guards, every unlock combination, normal spawning, movement, lethal damage, once-only bounty and save reload. Mixed-traffic balance and crowded-world tests include all four enemies.
- `rendered/enemy_art_checks.gd`: nine distinct native portraits, transparent export padding and visibility at four gameplay zooms; regenerates `assets/enemies/` and `artifacts/enemy-lineup.png` through `-ArtSmoke` or `-Check`.
- `unit/relocation_checks.gd`: move pricing and time caps, destination and balance guards, tower identity and earnings, construction combat restrictions, historical production cleanup, old saves, offline countdowns and clock replay protection.
- `rendered/relocation_ui_checks.gd`: all tower types using mouse and touch at small and large viewports; quote/cancel/place flow, duplicate callbacks, scaffold screenshots, rebuild restrictions, saved destinations, Escape and navigation cleanup. Tower menu checks exercise all five actions at four zooms; style checks include both the move quote and destination prompt.
- `unit/economy_checks.gd`, `tower_economy_checks.gd`: starter loop, collections, purchase guards, upgrade/sale integrity and production cleanup.
- `unit/tower_progression_checks.gd`: three-level cap for every tower, exact upgrade spending and refunds, combat attack intervals, version-one migration, once-only refunds and interrupted recovery.
- `unit/tower_balance_checks.gd`: 264 two-minute enemy cohorts across three seeds and four approaches, affordable openings, increasing upgrade income, mixed traffic at base/max density, and combined level-three defenses. Writes `artifacts/tower-balance.csv`.
- `unit/combat_checks.gd`, `attack_effect_checks.gd`: enemy roles, splash, core escapes, route junctions, per-tower First/Last/Most HP selection, deterministic ties, saved targeting and legacy defaults, cosmetic effects and pooled targets.
- `unit/developer_balance_checks.gd`: every editable stat, finite bounds, save round trips, defaults, independent games, live health/speed/rewards, tower attacks, prices and resets.
- `rendered/developer_controls_checks.gd`: mouse/touch/keyboard numeric fields and step buttons, every selectable type, immediate model updates, save-on-exit and reopening saved values.
- `unit/world_checks.gd`, `routing_checks.gd`, `terrain_checks.gd`: seeded expansion, shortest/equal routes, legacy saves, road clearance and terrain persistence.
- `unit/persistence_checks.gd`, `review_regressions.gd`: clocks, offline rewards, schema validation, reset, corrupt/interrupted saves, preservation of recovery files and invalid service inputs.
- `unit/input_checks.gd`: headless mouse/touch gesture and map hit-target checks.
- `unit/simulation_checks.gd`: all-territory simulation, thousands of enemies and one simulated hour. Timing is reported without a hardware-specific pass threshold.
- `rendered/visual_runner.gd`: launches a disposable application and runs the full UI harness, including tower dialogs and camera-independent combat comparisons.
- `offscreen_portal_runner.gd`: focused rendered regression, run with `Godot --path . --script tests/offscreen_portal_runner.gd`. Keeps all 32 portals outside the camera for a simulated minute, hides the battlefield halfway through, and checks sustained spawning, arrivals at the core, and exact enemy/timer agreement with a simulation-only reference.
- `rendered/terrain_palette_checks.gd`: all ordered biome pairs, four directions and four zooms; calls boundary/grid checks.
- `rendered/artwork_smoke.gd`: native artwork interactions and layouts at 540x960 and 360x640.

Headless assertion totals can change when obsolete implementation-specific checks are removed. The retired blending-mask checks were removed with their unused subsystem; shared-edge appearance is still checked by GPU pixel tests.

## Outputs and isolation

Logs, reports and screenshots are regenerated under `artifacts/`, which remains excluded from imports, source control and exports. `artifacts/.gdignore` is intentional. A test failure must be assessed from its current report/log, not an old screenshot.

The launcher uses `.runtime/tests/` for all test user data. Direct engine invocations should likewise use an isolated environment. Test app entry points additionally use explicit disposable save names before adding the app to the scene tree.

For a clean-checkout check, copy source and configuration to an isolated directory without `.godot`, `.runtime` or generated artifacts; retain an empty `artifacts/` with `.gdignore`; then run `./launch.ps1 -Check`. Do not erase the original `.runtime` directory because it contains player saves.

## Limits

Rendered checks use the native Godot engine, not a browser. Desktop-generated touch events are not physical-device testing. Export-package content checks do not replace running an installed Windows or Android release build.

## Developer tier controls

`rendered/developer_layout_checks.gd`, included in `-StyleTests` and `-Check`, opens every registered category with mouse/touch, checks every type and tower tier at all three phone sizes, and captures `artifacts/developer-layout-*.png`. It verifies single-line titles without clipping, square 48×48 navigation buttons, top-right dismissal, immediately visible selectors, bounded illustrated selection menus, complete numeric labels, reachable field/reset rows, and returning to the top when switching categories. Audio is muted in this layout-only fixture.

Run `Godot --headless --path . --script tests/developer_tiers_runner.gd` for schema limits, independent tier edits, branch prices/refunds, cooldowns, ability behavior and persistence. These tests are also included in the main headless runner. Run `Godot --path . --script tests/rendered/developer_tiers_runner.gd` for mouse/touch/keyboard step buttons and type-in fields, every tower tier and specialization, numeric input, responsive layout and save/reload. The rendered run captures `artifacts/developer-tier-frostneedle.png` and `artifacts/developer-tier-frostneedle-abilities.png`. Test saves have disposable developer-specific names.

## Relic equipment

The revised roster also runs `unit/gear_rework_checks.gd`: actual ground damage and overlap, area-stun boundaries and immunity, credited-kill stacks, range acquisition, scaling Pyre blasts, component reassignment/removal, campaign cleanup and retired Lantern settings. `rendered/gear_gameplay_runner.gd` opens every item at 360×640, 390×844 and 540×960 in both modes and checks the equipped range circle and upgrade comparison. `rendered/gear_art_runner.gd` exports all eighteen native illustrations to `assets/gear/`, verifies transparent padding and small silhouettes, and renders the parchment board. The art runner is included in `-ArtSmoke` and `-Check`.

The main headless suite includes `unit/relic_checks.gd` for guaranteed drops, transfers, ownership validation, legacy rewards, save roundtrips, and combat across every tower and specialization. Run Godot with `--path . --script tests/rendered/relic_runner.gd` for equipment mouse/touch interactions and responsive screenshots at three sizes.

Run `--headless --path . --script tests/gear_runner.gd` for the eighteen-piece catalog, complete boss sets, every gear tuning field, reusable attribute composition, damage/status effects, removal, pooling and legacy save migration. These checks also run in the full unit suite. Run `--path . --script tests/rendered/gear_menu_checks.gd` for every Gear editor field at 360×640, 390×844 and 540×960, source-boss descriptions, exact defaults, illustrated selection menu sizing, reset and save-on-close. It produces `artifacts/gear-lineup.png` and per-piece editor screenshots.

## Mobile action rows

Run Godot with `--path . --audio-driver Dummy --script tests/rendered/mobile_scroll_runner.gd` to exercise the real cloud panel with an offline service fixture at 360×640, 390×844, and 540×960. The test enables desktop touch emulation and checks that dragging row text scrolls, tapping text never syncs, the trailing Upload button activates once, busy actions are disabled, and action targets leave at least 60% of each row for scrolling. It also checks sound and developer number rows: label drags preserve values, typed values update the model, plus/minus buttons apply one step, and bounds disable the corresponding button. Screenshots are saved as `artifacts/mobile-cloud-rows-*.png`. This does not replace physical-device testing.


## Save modes and setups

Run Godot with `--headless --path . --script tests/save_slots_runner.gd` for three-slot isolation, legacy saves, named setup round trips into both modes, developer mutation guards, reset behavior, corrupt exports and slot archival. Run `--path . --audio-driver Dummy --script tests/rendered/save_slots_runner.gd` for the picker at three mobile sizes, world configuration selection, mode creation, configuration fields, Survival editor/camera restrictions and switching saves. Disposable test filenames keep player saves untouched.

## Account names

Run `--headless --path . --script tests/cloud_service_runner.gd` for account-name validation, save responses, session refresh and sign-in restoration. Run `supabase/tests/player_names_contract.sql` as postgres for transactional profile creation, name updates, Unicode limits, malformed metadata and account isolation. All SQL fixtures roll back. The private Auth trigger projects account metadata into `player_profiles` in the same transaction; the migration also backfills existing accounts, including those without cloud worlds.

## Public Builds

Run `--headless --path . --script tests/public_builds_runner.gd` for persistent offline uploads, unnamed accounts, account isolation, and stable retry IDs. Run `--path . --audio-driver Dummy --script tests/rendered/public_builds_runner.gd` for three phone sizes, catalog selection, Survival configuration import, and network failures. `supabase/tests/public_builds_contract.sql` checks publication, idempotency, author attribution, public reading, and denied mutations inside a rolled-back transaction.

## Backend acceptance and real gameplay

- Run Godot with `--headless --path . --script tools/cloud_payload_fixtures.gd`, then `python3 tools/backend_table_checks.py`. Execute `artifacts/backend-table-checks.sql` as postgres via Supabase SQL/MCP or psql. It uses eight real durable-save fixtures and checks all 14 application tables, including custom world rules, exact row/RPC readback, revision updates, duplicate retries, conflicts, rejected writes, and account isolation. Fixtures and mutations are rolled back. Run `supabase/tests/cloud_contract.sql`, `player_names_contract.sql`, and `public_builds_contract.sql` for additional constraints and permissions.
- Run `python3 tools/cloud_qa.py --headless --runner tools/cloud_live_runner.gd` for the real authenticated HTTP workflow. This creates a new QA world and leaves it for inspection; do not run indefinitely because accounts have a ten-world limit. It verifies token refresh, offline retries, restore, conflicts, disabled automatic uploads, and custom Survival rules.
- Run `python3 tools/cloud_qa.py` for manual play through the real menus. Click **Sign in to QA account** and use the isolated QA slots. After each gameplay change, pause, open Account & backups and upload the selected slot. Run `python3 tools/backend_verify_save.py /absolute/path/to/cloud-acceptance.save` (or the QA slot-2/slot-3 file), then execute `artifacts/backend-verify-save.sql`. It compares durable gameplay state with physical backend rows. Pause before syncing so ordinary combat does not make the snapshots differ. The moving clock and cosmetic fields are excluded.
- Run Godot with `--headless --path . --script tests/cloud_restore_runner.gd` to exercise the actual app restore handler, durable mode/rules restoration, and save-switch status. `tests/cloud_codec_runner.gd` includes default sound preferences and legacy/new cloud formats. `tests/rendered/save_slots_runner.gd` checks that Upload build is at the bottom of Creative settings and explains the Survival restriction.

The QA launcher is an authentication convenience for local testing, not an authentication bypass. It never gives the game an admin key. Existing player saves are separate from QA saves. Public uploads from manual testing remain visible under the QA author; automated SQL public-build fixtures roll back.

## Mourning Orchard

`--headless --path . --script tests/orchard_runner.gd` checks 100 world seeds for one connected 6–9 tile patch, ruin/opening clearance, deterministic regeneration, one portal, exclusive spawns (including escort rejection), traffic, movement, bounty/history, every developer stat, save/config/cloud-codec round trips and all tower/specialization combinations against the new foes. These checks also run in the main headless suite.

`--path . --audio-driver Dummy --script tests/rendered/orchard_runner.gd` opens the real portal using mouse/touch, checks all three Developer Controls entries and typed edits at 360×640, 390×844 and 540×960, captures terrain/portal/editor screenshots, and runs the existing complete developer input harness. The enemy artwork runner exports nine transparent portraits and checks four gameplay zooms. Terrain palette and edge checks include all six terrain styles.

`python3 tools/cloud_qa.py --headless --runner tools/orchard_live_runner.gd` uses the existing normal QA account to upload an Orchard save, sync a later stat edit, publish/read a configuration and import it into Survival. It writes the exact created IDs to `artifacts/orchard-live-evidence.json`. Verify the corresponding `regions`, `world_rules` and `public_builds` rows, then remove only these temporary QA records via SQL. This is opt-in because it creates a cloud world and a public test configuration.

## Campaign

- `--path . --script tests/rendered/campaign_terrain_checks.gd`: all 20 levels at 360, 390 and 540 pixels wide. Compares rendered roads against continuous authored geometry at four zooms and two fractional camera offsets, then checks bare ground at three zooms (660 cases). Captures each full level as `artifacts/campaign-terrain-LEVEL-WIDTH.png`. Included in `-TerrainTests` and `-Check`; roads stay visible during the road comparison so tile clipping cannot hide behind a passing ground-only test.
- `--headless --path . --script tests/campaign_runner.gd`: authored layouts and waves, finite mission rules, real tower transactions, boss routing and escorts, fresh-level restart, completion counts, migration, unlocks and corrupt-save recovery.
- `--headless --path . --script tests/campaign_balance_runner.gd`: legal reference defenses across all 20 levels, spending only starting gold and actual rewards. Writes `artifacts/campaign-balance.csv`.
- `--path . --audio-driver Dummy --script tests/rendered/campaign_runner.gd`: campaign navigation, construction, upgrades, wave starts, unfinished-level restart and sandbox isolation at three mobile viewport sizes. Captures `artifacts/campaign-*.png`.

Campaign test saves use unique disposable paths. The campaign save is a separate local format and does not consume a sandbox slot.

## Manual backups

`tests/campaign_backup_runner.gd` checks explicit Campaign uploads, durable manual retries, conflicts, account separation and restore. `tests/manual_backups_runner.gd` checks inactive Infinite slot uploads without simulating offline income or modifying other slots. Both run headlessly with synthetic transport. `supabase/tests/campaign_backups_contract.sql` exercises the scalar Campaign API and permissions inside a rolled-back transaction. Timer, restart and sign-in tests in `cloud_service_runner.gd` and `public_builds_runner.gd` prohibit automatic uploads. The older backend table fixture covers the fourteen pre-Campaign tables; use the Campaign contract in addition.

## Focused improvement regressions

Use the same Godot executable and isolated user data as above. Headless scripts accept `--headless --path . --audio-driver Dummy --script tests/<name>.gd`; rendered scripts omit `--headless` and live under `tests/rendered/`.

- `save_slots_runner`: custom starting gold, typed input, existing balances, world-build compatibility and mode isolation. `stat_configuration_runner`: strict stats-only schema, malformed data, local library, fresh worlds and Survival reset. Each has a rendered counterpart.
- `campaign_configuration_runner` and its rendered counterpart: shared stat controls, resource/spawn-group bounds, level/wave inheritance, default compatibility and saved draft application. `campaign_export_runner`: deterministic reports across all 20 levels, wave deltas and agreement with actual spawn statistics.
- `campaign_reset_runner` and its rendered counterpart: archive/recovery, confirmation/cancellation, persistent progression reset and preservation of unrelated world/configuration data. The UI check ignores only save revision/timestamp changes caused by desktop focus notifications.
- `rendered/campaign_selection_runner`: selection cleanup on action, removal, dialog, wave and navigation transitions. `rendered/campaign_upgrade_runner`: real mouse/touch upgrades and specializations on every campaign level, plus affordability, reconstruction, stale selection and maximum-tier guards. `touch_scroll_scope_runner`: scroll observer boundaries after reparenting. `rendered/upgrade_cost_runner`: visible authoritative prices, rule changes and actual spending at three viewport sizes.
- `poison_arrow_runner`: refresh without same-source stacking, independent sources, unassigned types, component replacement/removal, pooling and legacy branch persistence. Existing gear, branch and attack-effect suites cover the shared component behavior.
- `audio_pitch_runner`: repeated playback bounds, independent audio randomness, excluded cues and missing assets. `audio_runner` and `python3 tools/validate_audio.py` cover catalog routing and all generated assets. The generator changes only Frostneedle attack and impact timbre.
- `account_session_runner`: fresh/corrupt/project-mismatched credentials, token rotation, concurrent refresh, interrupted writes, transient/revoked sessions and sign-out races. `cloud_service_runner`, `manual_backups_runner` and `rendered/player_name_runner` cover shared account/menu behavior and prohibit automatic uploads.
- `python3 tools/test_account_session_http.py --godot /absolute/path/to/Godot --project /absolute/path/to/project` starts a localhost HTTP fixture and three separate Godot processes. It verifies sign-in persistence, startup refresh, rotation and logout across process restarts using actual `HTTPRequest`. It does not use the production backend or send email.

These fixtures supplement the full headless suite and the 20-level legal campaign reference playthrough. Rendered tests use desktop mouse and synthetic touch; production account acceptance, physical devices and TestFlight delivery are separate checks.
