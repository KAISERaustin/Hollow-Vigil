# Verification

Use the root `launch.ps1` commands documented in the README. `-Check` runs headless, full rendered UI, GPU terrain and artwork checks sequentially. The runner prepares imports, checks script compilation, isolates test saves under `.runtime/tests`, and fails on script/engine errors. Each automated test entry point has a timeout for interrupted or failed coroutines.

`./launch.ps1 -StyleTests` checks eleven UI screens at 540×960, 360×640, and 390×844 with 100%, 125%, and 150% text. It verifies viewport containment and reachable close/confirmation controls and captures `artifacts/style-*.png`. It is also included in `-Check`. Tower action targets remain at least 48 units at all map zoom levels; they are clamped inside the battlefield.

## Coverage

- `unit/economy_checks.gd`, `tower_economy_checks.gd`: starter loop, collections, purchase guards, upgrade/sale integrity and production cleanup.
- `unit/combat_checks.gd`, `attack_effect_checks.gd`: enemy roles, splash, core escapes, route junctions, cosmetic effects and pooled targets.
- `unit/catalog_checks.gd`: shared definitions, future content and fractional values.
- `unit/world_checks.gd`, `routing_checks.gd`, `terrain_checks.gd`: seeded expansion, shortest/equal routes, legacy saves, road clearance and terrain persistence.
- `unit/persistence_checks.gd`, `review_regressions.gd`: clocks, offline rewards, schema validation, reset, corrupt/interrupted saves, preservation of recovery files and invalid service inputs.
- `unit/input_checks.gd`: headless mouse/touch gesture and map hit-target checks.
- `unit/simulation_checks.gd`: all-territory simulation, thousands of enemies and one simulated hour. Timing is reported without a hardware-specific pass threshold.
- `rendered/visual_runner.gd`: launches a disposable application and runs the full UI harness, including tower dialogs and camera-independent combat comparisons.
- `rendered/terrain_palette_checks.gd`: all ordered biome pairs, four directions and four zooms; calls boundary/grid checks.
- `rendered/artwork_smoke.gd`: native artwork interactions and layouts at 540x960 and 360x640.

Headless assertion totals can change when obsolete implementation-specific checks are removed. The retired blending-mask checks were removed with their unused subsystem; shared-edge appearance is still checked by GPU pixel tests.

## Outputs and isolation

Logs, reports and screenshots are regenerated under `artifacts/`, which remains excluded from imports, source control and exports. `artifacts/.gdignore` is intentional. A test failure must be assessed from its current report/log, not an old screenshot.

The launcher uses `.runtime/tests/` for all test user data. Direct engine invocations should likewise use an isolated environment. Test app entry points additionally use explicit disposable save names before adding the app to the scene tree.

For a clean-checkout check, copy source and configuration to an isolated directory without `.godot`, `.runtime` or generated artifacts; retain an empty `artifacts/` with `.gdignore`; then run `./launch.ps1 -Check`. Do not erase the original `.runtime` directory because it contains player saves.

## Limits

Rendered checks use the native Godot engine, not a browser. Desktop-generated touch events are not physical-device testing. Export-package content checks do not replace running an installed Windows or Android release build.
