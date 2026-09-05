# Architecture and extension guide

## Ownership

`VigilState` owns one shared data dictionary and coordinates `VigilEconomy`, `VigilCombat`, world routes and `VigilSaveStore`. The state/economy/combat services can run without an active scene or GPU. `VigilApp` connects those services to the interface and owns timing, notifications and save calls. `VigilHUD` builds and updates the persistent header/footer and emits user intent through signals.

UI panels and tower dialogs have typed `VigilApp` references. That dependency is deliberate for this small application. When adding an independent screen, pass its model and use signals for user actions rather than adding more access through the scene tree. Keep purchases in the economy service, never inside draw functions or animation callbacks.

`Battlefield` handles map drawing, hit testing and camera gestures. Terrain is cached in one node per territory; the shared grid only draws visible rows and columns. Appearance changes increment `terrain_revision`. The retired blending adjacency cache, shader and image atlases have been removed.

Cosmetic attack effects are value snapshots. They never retain pooled enemy objects or issue delayed damage or payouts. The existing effect factory is shared with combat; drawing only consumes the resulting records. Camera position cannot affect spawn, targeting or rewards.

## Invariants

- Economy methods validate an action before spending. Upgrades and sales accept an expected level; panels also invalidate stale callbacks when navigation changes.
- A kill marks the enemy dead before issuing its one payout. Invalid damage and unknown enemy definitions are rejected.
- Every owned rift runs on the fixed 20 Hz simulation clock. Visibility only affects drawing. Live enemies retain their route when territory changes.
- Connected territory uses breadth-first shortest routes. Equal exits are chosen independently; decorative road bends do not change route choice.
- Offline income derives from actual historical earnings and a monotonically increasing accounting timestamp. Backward clocks cannot replay an interval.
- Terrain configuration is reusable: configuring a node again replaces roads and scenery.

## Save contract

Version 1 snapshots are JSON inside a checksummed envelope. The primary, `.tmp`, and `.bak` candidates are validated independently and the highest valid sequence wins. Validate data before touching the temporary file; flush and verify it before rotating the primary. An invalid attempted write must not destroy a newer interrupted save.

Existing version 1 saves keep their regions, balances, tower IDs and upgrades. Missing appearance fields receive the established defaults. Legacy road version 1 remains supported; it is compatibility code, not dead code. Fields such as road side and tower angle remain in the schema to preserve existing snapshots.

When all existing candidates are unreadable, loading reports the problem and blocks automatic overwrites. The player can restore a recovery file or explicitly reset. A successful reset writes fresh progress and replaces the recovery copy. Never silently reinterpret an unsupported save version as a new game.

For a future schema change, add a pure migration at the storage boundary and test old fixtures, round trips, interrupted writes and rejection of unknown versions. Keep unrelated settings when loading. Do not add live enemies, rendering nodes or cached terrain to saves.

## Adding content

- **Tower:** add its definition in `scripts/model/balance.gd`. The build menu and field guide read the definitions. Add its artwork in `scripts/rendering/terrain_art.gd`. New combat mechanics need explicit combat implementation and tests; adding a display field alone does not implement behavior.
- **Enemy:** add its definition, unlock cost and spawn share in `Balance`. Unlock validation, spawning and rift text read those tables. Shares must leave room for the basic enemy. Add artwork and test distribution, movement and rewards.
- **Biome:** update world style lists and its drawing palette/scenery. Save validation and GPU tests use the same world style names. Existing territories must keep their saved appearance.
- **Displayed statistic:** add a descriptor to `scripts/ui/info_catalog.gd`; preserve fractional values. Use balance data for text instead of copying gameplay numbers into panels.
- **Progression limit:** use the shared constants, including `MAX_TOWER_LEVEL`, in gameplay, validation and UI.
- **New feature:** add a focused module with a clear owner. Avoid a general framework until multiple concrete features need it. Keep public service methods typed and add boundary tests for state-changing behavior.

## Scaling and future work

The shared dictionaries are a pragmatic serialized model for this size of game. Keep mutations inside the owning services. If state grows substantially, introduce typed records and conversion at the save boundary incrementally rather than replacing every dictionary at once.

World size and active enemies remain uncapped by design. Very large worlds need profiling on target hardware; likely hotspots include route rebuilding, full-world scans and recent-income event storage. Do not suppress offscreen simulation as a performance shortcut.

Gold uses finite floating-point values capped at `1e150`. It is not suitable for exact single-unit accounting at astronomical values. The existing automation flag and collection behavior are retained for saved games and tests; a steward purchase is not exposed by the current interface.

Use `.editorconfig` and keep files focused by responsibility. Keep future features in focused version-control commits. A CI job can install the pinned engine, import the project and invoke `tests/test_runner.gd`; rendered suites require a real graphics environment.
