# Verification

Use the root `launch.ps1` commands documented in the README. `-Check` runs headless, full rendered UI, GPU terrain and artwork checks sequentially. The runner prepares imports, checks script compilation, isolates test saves under `.runtime/tests`, and fails on script/engine errors. Each automated test entry point has a timeout for interrupted or failed coroutines.

`./launch.ps1 -StyleTests` checks fifteen UI screens, including tower information, Developer Controls, targeting, and relocation, at 540×960, 360×640, and 390×844 with 100%, 125%, and 150% text. It verifies viewport containment and reachable close/confirmation controls and captures `artifacts/style-*.png`. It is also included in `-Check`. Tower action targets are 48 map units at baseline zoom; their size and offsets scale with their towers, including at screen edges. Rendered smoke checks cover mouse and touch at four zooms and three viewport sizes.

## Coverage

- `unit/enemy_checks.gd`: Lantern Keeper attunement pricing and guards, every unlock combination, normal spawning, movement, lethal damage, once-only bounty and save reload. Mixed-traffic balance and crowded-world tests include all four enemies.
- `rendered/enemy_art_checks.gd`: four distinct native portraits, transparent export padding and visibility at four gameplay zooms; regenerates `assets/enemies/` and `artifacts/enemy-lineup.png` through `-ArtSmoke` or `-Check`.
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

Run `Godot --headless --path . --script tests/developer_tiers_runner.gd` for schema limits, independent tier edits, branch prices/refunds, cooldowns, ability behavior and persistence. These tests are also included in the main headless runner. Run `Godot --path . --script tests/rendered/developer_tiers_runner.gd` for mouse/touch/keyboard step buttons and type-in fields, every tower tier and specialization, numeric input, responsive layout and save/reload. The rendered run captures `artifacts/developer-tier-frostneedle.png` and `artifacts/developer-tier-frostneedle-abilities.png`. Test saves have disposable developer-specific names.

## Relic equipment

The main headless suite includes `unit/relic_checks.gd` for guaranteed drops, transfers, ownership validation, legacy rewards, save roundtrips, and combat across every tower and specialization. Run Godot with `--path . --script tests/rendered/relic_runner.gd` for equipment mouse/touch interactions and responsive screenshots at three sizes.

## Mobile action rows

Run Godot with `--path . --audio-driver Dummy --script tests/rendered/mobile_scroll_runner.gd` to exercise the real cloud panel with an offline service fixture at 360×640, 390×844, and 540×960. The test enables desktop touch emulation and checks that dragging row text scrolls, tapping text never syncs, the trailing Sync button activates once, busy actions are disabled, and action targets leave at least 60% of each row for scrolling. It also checks sound and developer number rows: label drags preserve values, typed values update the model, plus/minus buttons apply one step, and bounds disable the corresponding button. Screenshots are saved as `artifacts/mobile-cloud-rows-*.png`. This does not replace physical-device testing.


## Save modes and setups

Run Godot with `--headless --path . --script tests/save_slots_runner.gd` for three-slot isolation, legacy saves, named setup round trips into both modes, developer mutation guards, reset behavior, corrupt exports and slot archival. Run `--path . --audio-driver Dummy --script tests/rendered/save_slots_runner.gd` for the picker at three mobile sizes, world configuration selection, mode creation, configuration fields, Survival editor/camera restrictions and switching saves. Disposable test filenames keep player saves untouched.

## Public Builds

Run `--headless --path . --script tests/public_builds_runner.gd` for persistent offline uploads, unnamed accounts, account isolation, and stable retry IDs. Run `--path . --audio-driver Dummy --script tests/rendered/public_builds_runner.gd` for three phone sizes, catalog selection, Survival configuration import, and network failures. `supabase/tests/public_builds_contract.sql` checks publication, idempotency, author attribution, public reading, and denied mutations inside a rolled-back transaction.
