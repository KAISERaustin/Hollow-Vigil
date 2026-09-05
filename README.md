# Hollow Vigil

A playable, portrait-oriented dark fantasy idle tower defense prototype built with the downloaded **Godot 4.7.2** and GDScript. The workspace was empty, so there was no existing implementation, art, or repository guidance to preserve.

## Play

For a native iPhone installation, see [IPHONE_SETUP.md](IPHONE_SETUP.md). An iOS export preset is included; building and signing the app requires a Mac with Xcode and an Apple signing account. No iPhone installation or device validation has been completed.

Open `project.godot` in Godot and press **F5**, or run `./launch.ps1` in PowerShell from this directory. `./launch.ps1 -Editor` opens the editor. The launcher points to the engine in the user's Downloads folder and keeps desktop saves and editor caches under this project's `.runtime` directory. Opening the project directly without the launcher uses Godot's normal per-user data directory instead; these are separate save locations.

The first Ashneedle tower is free. New games start with 280 gold: purchase your first territory for 100 gold, leaving 180 for defenses. The starting tile contains only the core and tower sockets, with no rift or enemy spawns. Every purchased territory spawns enemies from a rift at its center.

- Watch continuous enemies emerge from the rifts and follow the roads into the **CORE**, a mint-ringed portal in the center of the starting territory. Every enemy that survives escapes through this one portal. Tap the core for details: escapes cost no gold and cause no damage. There are no waves, lives, deadlines, or game-over states.
- Tap a tower to collect its stored gold immediately and reveal three buttons: **Info** (i) on the left, **Upgrade** (double chevron) below, and **Sell** (coin with a minus) on the right. Each is 48 map units wide and 78 map units from the tower center. Buttons and gold badges keep fixed proportions relative to their tower, scaling together with its artwork as you zoom. Their layout does not rotate or change with tower range or screen position. Selecting a tower leaves the camera where it is; pan manually to reach controls clipped by the map edge. All tower gold badges and their click areas hide while tower controls or a tower dialog are open. Tapping empty ground dismisses the controls and restores badges for towers with unclaimed gold. **Collect all** remains available outside confirmation dialogs.
- Each button opens a centered dialog with confirm and cancel controls. Info shows damage per hit, fire rate (shots per second), theoretical DPS per target, range, attack interval, and blast radius for splash towers. Upgrade previews the next level, cost, and remaining gold before purchase. Sell previews a refund of **50% of the build and upgrade costs**, rounded down, plus all stored gold; confirmation removes the tower and frees its socket. Cancel changes nothing. There are no hover text popups, and the dialogs block map and footer actions until dismissed.
- Choose the **Info** icon in the top-right corner for the **Towers** and **Enemies** guide. Browse tower abilities, level 1 damage, attack interval, reach, build cost and blast radius; switch to Enemies for health, move speed and defeat rewards, including foes not yet attuned. The list scrolls while the tabs and close button stay visible.
- Build defenses around the core using its four surrounding stone sockets. Tap an empty socket, choose a tower, inspect its range and price, and confirm **Build**. The close button cancels without spending.
- Tap a **+** beyond the roads to purchase connected territory. Every region adds a rift, four tower sockets, and stable roads.
- Tap a rift or choose **Rifts** to increase its traffic or introduce wraiths and revenants. Additional targets only become additional income if defeated.
- Drag to pan; pinch or use the mouse wheel to zoom. Drag and pinch releases do not place towers.
- Tower actions and earnings badges use fixed map sizes and offsets, including their icons, text, borders and click targets. Zooming out reduces them together with the tower, so they never grow relative to its artwork. The core and rifts have no map text labels, and towers have no level dots. The HUD and dialogs keep their screen layout; socket plus signs, selection markers and enemy health bars retain fixed screen sizes. Terrain, world artwork and the attack-range preview follow the map zoom.
- Open **···** for 30 FPS power saving, Lifetime gold and Escaped statistics, and **Return to the core**.

## Reusable architecture

| File | Responsibility |
| --- | --- |
| `project.godot`, `scenes/main.tscn` | Engine configuration and entry scene |
| `scripts/main.gd` | App lifecycle, fixed-step scheduling, persistent HUD, save timing |
| `scripts/balance.gd` | Tower/enemy definitions, costs, progression, spawning and formatting |
| `scripts/economy.gd` | Validated purchases, upgrade guards, collection and credits |
| `scripts/world.gd` | Seeded winding roads, shortest routes through owned tiles, frontier and tower sockets |
| `scripts/combat.gd` | Continuous streams, pooled enemies, local target search, damage and kill attribution |
| `scripts/game_state.gd` | Shared model, expansion, offline accounting and load coordination |
| `scripts/save_store.gd` | Schema validation, checksummed snapshots, recovery and rotating writes |
| `scripts/battlefield.gd` | Flat outlined portals and towers, range previews, map hit targets and camera gestures |
| `scripts/terrain_topology.gd` | Derived eight-neighbor material IDs, occupied masks, same-biome masks and affected neighbors |
| `scripts/terrain_layer.gd`, `scripts/terrain_tile.gd` | Cached borderless terrain chunks, flat connected roads and safe scenery placement |
| `scripts/terrain_grid.gd` | One world-aligned grid over terrain, with tile-sized cells across owned and expandable territory |
| `scripts/terrain_art.gd`, `assets/terrain/` | Shared limited palette and native drawing helpers for scenery, sockets, portals, towers and enemies |
| `scripts/interface.gd` | Reusable typography, colors, buttons and layout components |
| `scripts/info_catalog.gd` | Read-only guide entries and stat descriptors sourced from the shared balance definitions |
| `scripts/field_guide.gd` | Reusable category tabs, scrolling cards and stat grids for the Info panel |
| `scripts/panels.gd` | Info, build, upgrade, expansion, rift and settings panels |
| `tests/test_runner.gd` | State and economic integrity tests without the visual game |
| `tests/visual_smoke.gd` | Rendered UI checks using real mouse and touchscreen input events |
| `export_presets.cfg` | Android ARM64, Windows and iOS export presets |

The economic model is independent of rendering. Enemy damage resolves synchronously and marks a defeated enemy before issuing its sole payout. Old confirmation callbacks carry a revision/level guard. Collection empties the same records used by tower indicators and the global total before changing the spendable balance. Animation never owns a transaction.

To extend the Info guide, add a tower or enemy to `Balance.TOWERS` or `Balance.ENEMIES` in `scripts/balance.gd`, with its gameplay stats, name, role, description and color. The guide automatically lists every definition, including locked enemies. Its cards use the same numbers as combat; tower values are explicitly level 1. A new displayed mechanic only needs a stat descriptor in `info_catalog.gd` (`key`, `label`, optional `suffix` and `positive_only`); the shared card renderer requires no per-type branch. These guide hooks do not implement new combat behaviors, artwork or enemy spawning rules.

## Persistence and idle behavior

Snapshots contain version, sequence, seed, regions, parent links and road bends, entrances, traffic, enemy unlocks, towers and upgrades, balances, per-tower earnings, lifetime statistics, automation, production history, camera, timestamps and settings. Roads are reconstructed deterministically from stored topology. Live enemies and visual effects are transient and are not restored.

Each write flushes a checksummed temporary snapshot, verifies its schema and checksum, rotates the valid primary to a backup, then promotes the temporary snapshot. Loading chooses the highest valid sequence among primary, temporary and backup. Purchases and collections save immediately; active play also saves every ten seconds and at supported lifecycle events.

Offline earnings use **80% of demonstrated net production**, including periods in which enemies escaped or nothing was defeated. Per-source history uses a three-minute smoothing horizon, with a minimum 60-second denominator. A new save with no demonstrated production gets zero estimated income. This avoids estimating income from spawn counts. Rewards go into the existing tower earning records; an unlocked steward collects them.

The reward and timestamp are committed together before interaction. Active play advances the accounting watermark, and suspension stops live ticks. Backward clock movement cannot lower the watermark; a forward absence contributes at most seven days. Extra time beyond that safeguard is discarded. Estimated offline kills **do not** increase lifetime kills, which tracks simulated defeats from every territory. Offline processing cannot buy, upgrade, or expand anything.

Storage has no gameplay capacity limit or expiry. Finite-value guards saturate at `1e150`; display formatting switches to scientific notation for huge balances. Floating point gold is suitable for this local prototype but does not preserve single-gold precision at astronomical magnitudes. Paid inventory or competitive economies would require another numeric representation.

## World and performance

Enemies use the fewest tile crossings through owned territory. Each equally short exit has the same independent chance per enemy (50/50 for two exits), including forks farther along the route. Decorative bends do not affect these choices. Buying a tile rebuilds route choices for all rifts, so new enemies can use newly opened equal routes or shortcuts. Each live enemy keeps its chosen route until it is defeated or escapes, with no mid-road switching when territory expands. Parent links record purchase history only.

Tiles append to an older adjacent parent. Every route ends at the core at world position (0, 0), so territory can expand outward around one fixed destination. Parent cycles, disconnected purchases, and occupied sockets are rejected. Each tile now has seeded sweeping or S-shaped paths, sampled into the exact same points for drawing and enemy movement. Shared edge centers and cardinal road mouths join neighboring tiles. Paths reserve clearance around all four tower sockets and do not move when adjacent territory is purchased. Their extra length slightly increases enemy travel time; no combat stats or prices changed. Existing saves retain their regions, towers, upgrades, and balances; saves without a road version reconstruct the new curves on load. Explicit version-1 routes remain supported. A single inward ring marks an escape through the core.

### Minimal palette artwork

The interface shares the terrain's parchment, road, black and ochre palette. HUD panels, menus, field-guide cards, dialogs, notifications and controls use solid 4-pixel black borders, small corners and bold headings. Coral identifies sale and reset actions; guide entries show the same tower and enemy artwork used on the battlefield. Compact build and rift content wraps and scrolls within the screen.

Unclaimed earnings and **Collect all** appear above the spendable-gold, production-rate and lifetime-kill cards. Collecting gold shows an ochre badge centered over the visible Unclaimed earnings caption, holds it briefly and floats it upward before fading.

All four biomes use flat colors: sage forest, clay forge, blue crypt and mauve sanctuary. Tiles draw no borders. One shared black grid overlays the terrain, with 300-unit cells matching the tile size and 6-unit lines centered on every boundary. It continues across road mouths and into unowned territory, stays aligned while panning and zooming, and draws only visible rows and columns so it can follow expansion in any direction. The cream roads still meet at the exact shared edge and enemies cross normally. There are no blended biome edges, painted textures, gradients or scenery shadows.

Towers use three small silhouettes: an ochre pointed tower, a coral brazier with one flame, and a lavender obelisk. The core and rifts are mint and purple rings with black centers. Enemies are simple outlined shapes with two eyes. Each tile contains at most three small biome props, kept away from roads, sockets and the full tower silhouettes. Buttons, labels and the app icon use the same flat style.

All active artwork is drawn with Godot shapes in scripts/terrain_art.gd, scripts/terrain_tile.gd and scripts/terrain_grid.gd. Static terrain remains cached per tile; the shared grid sits above all terrain chunks and below battlefield objects and controls. The former PNG atlases and shader remain as unused source history; the runtime does not load them. Artwork changes do not alter saved progress, road geometry or combat balance. See assets/terrain/ART_DIRECTION.md for the palette and drawing rules.
Combat uses a fixed 20 Hz step, spatial target buckets, no physics bodies, an enemy reuse pool, at most 100 effects, and visible-region drawing. Every purchased rift spawns and every tower fights on every simulation step, regardless of camera position or zoom. Live enemies remain on their routes until defeated or escaped. There is no camera-based stream selection, route budget, or global enemy limit that silently suppresses spawns. Active earnings and gold per second come only from actual defeats throughout the world.

New territory, traffic, enemy unlocks, and tower upgrades participate immediately even off-screen. Only drawing is restricted to the visible area; off-screen combat also updates the production history used for offline earnings. Very large worlds with long routes and high traffic require more simulation work and still need device profiling before production release.

## Verification

Run `./launch.ps1 -Tests` for the focused headless suite. It covers the full starter loop, duplicate hits and taps, collections, invalid/insufficient purchases, visible stat benefits, enemy roles, splash, continuous spawning, exact core escapes from every approach, all four surrounding defenses, 80 procedural expansions, stable roads after load, offline replay and clock guards, corrupted/interruptible saves, camera gestures, core/socket hit targets across zoom levels, simultaneous spawning and earnings across 33 territories, spawning beyond 900 live enemies, 81 max-traffic rifts with thousands of live enemies, and one simulated hour of idle play. The stress check prints simulation timing without imposing a hardware-dependent pass threshold. Results are written to `artifacts/test-results.txt`.

Run `./launch.ps1 -Smoke` for real rendered-engine screenshots and UI interaction checks. It uses an isolated `smoke.save`, never the player's save. It exercises touchscreen collection, touchscreen upgrades during collection animation, confirmed placement and expansion, and panel bounds. Screenshots and `visual-results.txt` are placed in `artifacts` and excluded from exports.

The camera regression compares 33 territories against an identical stationary simulation while repeatedly moving between opposite ends, zooming, returning to the core, and upgrading a distant rift and tower. Spawn counts, live enemy state, per-tower earnings, cooldowns, production history, kills, escapes, and gold per second must match exactly.

The Info checks also cover adding a future tower definition, preserving fractional stats, matching enemy health to actual spawned enemies, and keeping browsing read-only. Rendered checks exercise the Info button, both category tabs, mouse-wheel and emulated touch scrolling, close, and subsequent map socket building at 540×960 and 420×800. Touch scrolling is simulated on desktop; it has not been verified on a physical phone.

Run ./launch.ps1 -TerrainTests for native GPU checks of all 16 ordered biome pairs in all four directions at four zoom levels, with negative world coordinates and fractional camera offsets. The checks verify black grid lines along the entire shared edge (including the road crossing), cream road fills on both sides, distinct flat biome colors, and outer clipping across isolated, adjacent and L-shaped layouts. Additional grid checks cover new purchases, two viewport sizes, unowned cells, and camera positions 1,000 tiles from the core. Results are in artifacts/terrain-palette-results.txt, artifacts/terrain-edge-results.txt and artifacts/terrain-grid-results.txt. The main headless suite also checks road clearance, enemy movement and save compatibility.

Run `./launch.ps1 -TerrainPreview` to capture a four-biome junction, a larger mixed world, connected matching biomes and the starter tile. The preview creates a disposable world and never loads or writes player progress. These are native Godot rendered checks; no browser or physical-phone verification is claimed.


Run ./launch.ps1 -ArtSmoke for artwork-focused input checks: build and select the new towers, touch the core, open a rift, and open/close the field guide. It captures the full game at 540x960 and 360x640 using an isolated artwork-smoke.save. Screenshots use the minimal- prefix, and the report is artifacts/artwork-results.txt.

The Windows engine emits a root-certificate-store warning in this sandbox. This prototype uses no network services; the gameplay, rendering and local save checks run successfully.

## Assumptions and remaining work

- **Confirmed art direction:** very minimal flat drawing, a limited palette, borderless tiles and one thick black world grid. **Provisional choices:** Hollow Vigil title, portrait orientation, single gold currency and balance values.
- Player-controlled expansion, harmless escapes, uncapped storage, collect-all, optional steward automation and conservative offline income are implemented defaults.
- There is no audio in this version. Gameplay is fully understandable while muted. If added, music and effects should have separate controls.
- Android, Windows and iOS export presets are supplied. Installed export templates found on this machine are 3.4.1, 4.4 and 4.4.1, which do not match the downloaded 4.7.2 engine. Install matching 4.7.2 templates and configure signing/JDK paths before exporting an APK or standalone executable. Native iPhone builds additionally need a Mac with Xcode and an Apple signing account; see IPHONE_SETUP.md. The Android SDK exists locally, but no mobile package or physical-device validation is claimed.
- Test real phone safe areas, suspend/resume under OS termination, gesture behavior, battery use, temperature and long-session frame pacing. Desktop-simulated touch is not a substitute for device testing.
- Tune late progression and profile large-map combat and shape drawing on mobile hardware.
- Multiplayer, leaderboards, campaigns, prestige, skill trees, extra currencies, accounts, cloud sync and monetization remain out of scope.

Godot implementation references: [input event handling](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html), [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html), and [DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html).
