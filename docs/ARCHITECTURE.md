# Architecture and extension guide

## Ownership

`VigilState` owns one shared data dictionary and coordinates `VigilEconomy`, `VigilCombat`, world routes and `VigilSaveStore`. The state/economy/combat services can run without an active scene or GPU. `VigilApp` connects those services to the interface and owns timing, notifications and save calls. `VigilHUD` builds and updates the persistent header/footer and emits user intent through signals.

UI panels and tower dialogs have typed `VigilApp` references. That dependency is deliberate for this small application. When adding an independent screen, pass its model and use signals for user actions rather than adding more access through the scene tree. Keep purchases in the economy service, never inside draw functions or animation callbacks.

`Battlefield` handles map drawing, hit testing and camera gestures. Terrain is cached in one node per territory; the shared grid only draws visible rows and columns. Appearance changes increment `terrain_revision`. The retired blending adjacency cache, shader and image atlases have been removed.

Cosmetic attack effects track enemy centers by serial ID, refreshing their position after movement and attacks. When a target dies or escapes, its last position is frozen before its dictionary is recycled. Effects never retain pooled enemy objects or issue delayed damage or payouts. `gameplay/combat/shot_factory.gd` owns projectile flight timing and creates effect records; `rendering/effects/attack_effects.gd` only draws them. Gameplay never imports presentation modules. Camera position cannot affect spawn, targeting or rewards.

## Source boundaries

- `gameplay/game_state.gd` coordinates the shared snapshot, live services and storage lifecycle. `gameplay/balance.gd` is the existing balance API and content catalog.
- `gameplay/combat/combat.gd` owns the simulation clock, enemy pool, pending shots, effects, target locks and transient ability/relic state. Its public methods remain stable for callers and tests.
- `gameplay/combat/targeting.gd` ranks supplied candidates using path distance, health and deterministic spawn-order ties; it needs no scene or game-state reference.
- `gameplay/combat/projectiles.gd` handles launch, flight, impact, fragments and ballistic arrows. `tower_abilities.gd` handles on-hit branch effects, displacement and persistent fire. These stateless helpers receive the owning combat service explicitly; they do not store a second copy of its state or retain it in a reference cycle.
- `gameplay/encounters/bosses.gd` owns encounter behavior. `gameplay/progression/` owns economy transactions and relic rules. Relocation, selling and equipment changes use one production-history invalidation helper.
- `world/` owns deterministic geography and routes. `persistence/` owns schema validation, migrations and recovery. Neither belongs in a screen or draw callback.
- `rendering/terrain/` owns map tiles, grids, clouds and castle scenery; `rendering/actors/` owns towers, enemies, bosses, rifts and relic icons; `rendering/effects/` consumes transient visual records.
- `ui/towers/` owns tower actions, dialogs, movement and equipment; `ui/developer/` owns tuning controls; `ui/shared/` owns reusable styling and widgets. Application composition stays in `app/`.

Keep each `.uid` alongside its script and update explicit `res://` references when moving files. Run `python3 tools/check_structure.py`, import with Godot, then run affected headless and rendered suites. A directory move does not change save keys, tower IDs, class names or resource UIDs.

## Invariants

- Economy methods validate an action before spending. Upgrades and sales accept an expected level; panels also invalidate stale callbacks when navigation changes.
- A kill marks the enemy dead before issuing its one payout. Invalid damage and unknown enemy definitions are rejected.
- Every owned rift runs on the fixed 20 Hz simulation clock. Visibility only affects drawing. Live enemies retain their route when territory changes.
- Connected territory uses breadth-first shortest routes. Equal exits are chosen independently; decorative road bends do not change route choice.
- Offline income derives from actual historical earnings and a monotonically increasing accounting timestamp. Backward clocks cannot replay an interval.
- Relocation validates ownership, vacancy, affordability and the expected tower level before charging. It keeps the tower ID, level and earnings, clears only that tower's old production history, and reserves its new socket immediately. `rebuild_remaining` advances on active ticks and accounted offline intervals; rebuilding towers cannot attack, upgrade or relocate. Older saves without that optional field load ready to fire.
- Terrain configuration is reusable: configuring a node again replaces roads and scenery.

## Save contract

Version 2 snapshots are JSON inside a checksummed envelope. The primary, `.tmp`, and `.bak` candidates are validated independently and the highest valid sequence wins. Validate data before touching the temporary file; flush and verify it before rotating the primary. An invalid attempted write must not destroy a newer interrupted save.

Version 1 candidates are validated against their original level limit, then migrated without changing the input or disk. Towers above level 3 become level 3; the full original rounded costs of levels 4+ return to spendable gold. Tower IDs, regions, stored earnings, settings, and levels 1–3 survive. Production history for capped towers is cleared so obsolete high-level output cannot fund future offline rewards; other history remains. Loading commits the migrated version, making refunds idempotent across reloads and recovery. Missing appearance fields receive the established defaults. Legacy road version 1 remains supported. Fields such as road side and tower angle remain in the schema to preserve existing snapshots.

When all existing candidates are unreadable, loading reports the problem and blocks automatic overwrites. The player can restore a recovery file or explicitly reset. A successful reset writes fresh progress and replaces the recovery copy. Never silently reinterpret an unsupported save version as a new game.

For a future schema change, add a pure migration at the storage boundary and test old fixtures, round trips, interrupted writes and rejection of unknown versions. Keep unrelated settings when loading. Do not add live enemies, rendering nodes or cached terrain to saves.

## Permanent castle ruins

`world/hidden_areas.gd` retains the original seeded four/five-cell sector footprints. Unowned footprints are excluded from the seeded expansion frontier; they never enter `regions`, so they have no ordinary portals, sockets, traffic or gameplay roads. Any footprint overlapping existing owned terrain is exempt as a whole, preserving legacy terrain, towers and boss records. The core and starter choices remain clear.

`world/castle_plan.gd` plans a complete structure in local coordinates, with courtyard, great-hall, keep and chamber-range variants. Its 60-unit architectural lattice crosses the 300-unit terrain boundaries. Only exposed footprint edges receive exterior walls; damage removes spans without moving shared vertices. Floors, corner foundations, fallen beams, rubble and the gate corridor share the same deterministic plan. Keep the versioned decoration stream stable for reload consistency. `rendering/hidden_areas.gd` draws complete nearby clusters above the terrain lattice, masking internal grid lines. Cloud banks do not cover the boundary against an ordinary region.

The gate chooses a seeded exposed side on one encounter tile and meets the neighboring road's exact endpoint. Purchasing that reachable neighbor awakens the encounter once. Boss movement samples run from 65 units inside, through the threshold, along that neighbor's road, then into existing patrol routing. Interior partitions reserve the approach clearance. Bosses never route back through decorative tiles.

Optional `castles` save records retain active, defeated and escaped encounters independently of terrain. Active positions and sampled routes are validated against either the authored emergence path or an ordinary patrol leg before writing or loading. Legacy region-based encounters retain their existing paths and statuses. `castle_checks.gd` verifies seed stability, outlines, expansion, movement and persistence; `castle_art_checks.gd` renders four plans at three zooms and checks identical offscreen returns. The latter runs under `launch.ps1 -TerrainTests` and `-Check`.

## Adding content

Developer balance is stored as sparse `settings.developer_balance` overrides per enemy/tower type. `Balance.TUNING_FIELDS` defines editable fields and finite bounds for both sliders and save validation; `Balance.definition`, `tuned_value`, and `stats` resolve values with defaults. Runtime consumers must pass the owning game's tuning instead of changing shared constants. `VigilState` applies edits, preserving live health and cooldown fractions and clearing stale production samples. `scripts/ui/developer/developer_controls.gd` owns the editor; the app debounces saves and flushes when leaving it. Saves without overrides keep the defaults.

- **Tower:** add its level-one definition, two `TOWER_UPGRADES` rows and two level-four `BRANCHES` entries in `scripts/gameplay/balance.gd`. Each upgrade row contains its purchase cost and complete combat stats; branch ability parameters live in `ABILITIES`. `Balance.stats()` caps levels and applies developer overrides in proportion to the tier's base values. The build menu reads the definitions and upgrade prices. Add its artwork in `scripts/rendering/terrain/terrain_art.gd`. Implement new projectile mechanics in `gameplay/combat/projectiles.gd` and on-hit or persistent effects in `tower_abilities.gd`, with behavior tests; adding a display field alone does not implement behavior.
- **Enemy:** add its definition, unlock cost and spawn share in `Balance`. Unlock validation, spawning and rift text read those tables. Shares must leave room for the basic enemy. Add artwork and test distribution, movement and rewards.
- **Biome:** update world style lists and its drawing palette/scenery. Save validation and GPU tests use the same world style names. Existing territories must keep their saved appearance.
- **Displayed statistic:** preserve fractional values. Use balance data for text instead of copying gameplay numbers into panels.
- **Progression limit:** use the shared constants, including `MAX_TOWER_LEVEL`, in gameplay, validation and UI.
- **New feature:** add a focused module with a clear owner. Avoid a general framework until multiple concrete features need it. Keep public service methods typed and add boundary tests for state-changing behavior.

## Sweep decisions

The September 2026 organization pass removed the unreferenced `UI.content_box()` helper and `UI.TITLE` constant. Native boss drawings made the old matte shader and empty frame hooks unnecessary; their call sites were removed as well. Reference checks included scripts, scenes and tests, including string-based references.

Legacy automation, appearance fields, save migrations, diagnostic runners and preview scripts remain intentional. Tests and saved progress still depend on them; absence from the current player interface does not make them dead code. Asset files remain available to the art/export workflows. No player saves or generated runtime directories were cleared.

## Scaling and future work

The shared dictionaries are a pragmatic serialized model for this size of game. Keep mutations inside the owning services. If state grows substantially, introduce typed records and conversion at the save boundary incrementally rather than replacing every dictionary at once.

World size and active enemies remain uncapped by design. Very large worlds need profiling on target hardware; likely hotspots include route rebuilding, full-world scans and recent-income event storage. Do not suppress offscreen simulation as a performance shortcut.

Gold uses finite floating-point values capped at `1e150`. It is not suitable for exact single-unit accounting at astronomical values. The existing automation flag and collection behavior are retained for saved games and tests; a steward purchase is not exposed by the current interface.

Use `.editorconfig` and keep files focused by responsibility. Keep future features in focused version-control commits. A CI job can install the pinned engine, import the project and invoke `tests/test_runner.gd`; rendered suites require a real graphics environment.
