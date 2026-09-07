# Hollow Vigil

A portrait idle tower-defense game built with Godot 4.7.2 and GDScript.

## Run

On macOS, double-click `launch.command` to play. Run `./launch.command --editor` to open the project in Godot. It uses Godot from Applications or Downloads, or the executable supplied in `GODOT_PATH`.

Open `project.godot` in Godot and press **F5**, or use PowerShell:

```powershell
./launch.ps1
./launch.ps1 -Editor
```

The launcher accepts `-GodotPath C:\path\to\godot.exe`, then checks `GODOT_PATH`, then Godot on PATH. It also retains the original Downloads installation as a fallback. Use the console executable on Windows. It imports resources before running so a fresh checkout does not depend on an existing `.godot` cache.

Player saves launched this way remain in `.runtime/Roaming/Godot/app_userdata/Hollow Vigil/`. Opening the project directly uses Godot's normal per-user save directory. Test runs use a separate `.runtime/tests/` directory. Do not delete `.runtime` as a whole: it contains player progress.

## Test on the Samsung tablet

Connect the tablet with USB, unlock it, enable USB debugging, and accept the authorization prompt. From the project folder, run:

```powershell
./run-tablet.ps1
```

This builds the **Android Tablet** debug APK, installs it as an update, and launches Hollow Vigil. Repeat after changing the game. The tablet keeps its own progress. If several Android devices are connected, select one with `-Device SERIAL` (shown by `adb devices`).

The preset uses the local templates in `exports/android-tools/` and the existing Android SDK. The script uses the configured export profile there. Those tools are ignored by Git and must be set up again on a different computer. The store bundle remains available under the **Android** preset and through `build-android.ps1`.

## Play

- New games start with **280 gold**, an empty core territory, and no enemies. Buy connected territory for **100 gold** to open the first rift. The first Ashneedle costs **60 gold**.
- Buy towers in stone sockets, collect their earnings, upgrade them, and expand. Every tower starts at **level 1**, upgrades through **level 3**, then chooses one of two permanent **level 4** branches. Click Upgrade, preview the left or right branch, then confirm the purchase. Ashneedle upgrades cost **60 / 100 gold**, Pyre **120 / 200**, and Obelisk **140 / 220**. See the [tower balance tables](docs/TOWER_BALANCE.md) for all four levels, branch powers, and total investment.
- Every unlocked non-castle tile has a portal that continuously spawns its own themed enemies. Each of the six portal types has exactly three inhabitants; see the [portal roster guide](docs/PORTAL_ROSTERS.md). Castle patches retain one dungeon portal; their other tiles provide roads and tower sockets. The core keeps its receiving portal. All enemies follow connected roads to the core; escapes cause no damage or gold loss.
- Select a tower to collect its stored gold and reveal Info, Upgrade, Sell, Move, and Target (the crosshair). At levels 1 and 2, tap Upgrade once to show a check mark, then tap again to upgrade. At level 3, preview and confirm a specialization instead. Selecting another tower or action cancels the pending confirmation. Sale refunds half its build and upgrade costs plus stored gold.
- Target lets each tower choose **First** (least road distance remaining to the core), **Last** (most road distance remaining), or **Most HP** (highest current health). Only enemies in range are eligible. Most HP locks its primary target until that enemy dies or leaves range, then chooses the highest-health enemy still in range. Taking damage or a healthier enemy arriving does not change the lock. Splash and multi-target attacks retain their secondary hits. First is the default, including for older saves. Select a mode and Apply targeting to save it for that tower. Equal HP prefers First on acquisition, with exact ties resolved by spawn order. Moving or upgrading retains the setting.
- Move shows the relocation price and rebuild time before you choose a destination. Tap a highlighted empty socket in any owned territory to pay 20% of the tower's current build and upgrade value (rounded up). Cancel before placement costs nothing. The tower keeps its level and stored gold, frees its old socket, and cannot fire, upgrade, or move again while rebuilding. A scaffold and countdown mark construction; time away also counts. Base rebuilds take 30 seconds for Ashneedle, 60 for Pyre, and 80 for Obelisk, plus 15 seconds per purchased upgrade, with a 180-second cap. Developer build-cost changes also scale the relocation price and base rebuild time.
- Drag to pan and use the mouse wheel or pinch to zoom the map. The HUD keeps a fixed screen size. Tower action buttons stay attached to their towers with a fixed map-space size and spacing, scaling together with the map. Gold badges sit above their towers in map space: their text, borders, spacing, and touch padding scale together with the tower, without independent enlargement. Settings include developer controls and reset; use the header’s X button to close the menu. The game uses a fixed 60 FPS cap, standard text size, and normal motion.
- Offline rewards use 80% of demonstrated production, capped at seven days. Rewards never purchase anything or inflate lifetime kill counts.

Castle ruin tiles can be purchased through connected expansion at the normal territory price. Each becomes a paved tile with four tower sockets; one tile per ruin holds the dark central dungeon portal. Only these portals spawn **Abyss Shades** (240 HP, 56 speed, 30 gold) and **Crypt Sentinels** (680 HP, 28 speed, 55 gold), both available immediately. Traffic upgrades increase their spawn rate. Existing boss encounters keep their progress when a ruin is claimed.

Stone clusters hide one boss each. Buying its assigned tile awakens it;
it patrols owned roads while avoiding the core, escaping only if the core is
its sole exit. Health and encounter
progress survive reloads, and each boss has a level-four tower weakness and
a one-time bounty. See [boss encounters and counters](docs/BOSSES.md).

Bosses also drop **relic equipment**. Select a tower and use the diamond button at the upper left of its action circle to equip, remove, or transfer a relic for free. Every tower has one slot; equipped towers display a matching boss emblem. Selling keeps the item, and older saves receive drops for recorded victories. See [boss relics and their effects](docs/RELICS.md).

## Mourning Orchard

One connected patch of 6–9 Orchard tiles is placed once per world seed, within nine tiles of the core and outside the first two expansion rings. It avoids castle ruins. Pale thorn trees, hanging burial urns, olive earth and a root-bound portal use the same native flat fills and black outlines as the existing terrain.

Every tile in the patch has its own portal. Each summons **Briarlings** (85 HP, 86 speed, 13 gold), **Veil Widows** (260 HP, 43 speed, 28 gold), and **Coffinbound** (820 HP, 22 speed, 64 gold), with equal chances and no attunement cost. Their knockback resistance is 0%, 25%, and 90%, respectively. They never appear in other biome portals or boss escorts. Portal traffic, towers, targeting, specializations, relics, bounty collection, offline income and camera-independent simulation use the existing systems.

All three appear in Developer Controls with editable health, movement speed, bounty and knockback resistance. Their edits persist in local saves, cloud backups, exported configurations, Public Builds and Survival imports. Existing purchased terrain keeps its saved appearance; new terrain is generated when claimed. An older world that already owns the seeded portal location keeps its original portal; start a new world to guarantee the complete Orchard.

## Campaign: The Last Procession

Open **Campaign · The Last Procession** from Saved games, or play it from Settings. Twenty handcrafted levels cross four regions in a separate campaign world, with predefined roads, planned waves and a boss every fifth level. Each mission starts with fresh gold and 20 flame; enemies reaching the sanctuary consume flame, and an escaped boss ends the mission. Gold is collected automatically. Build and upgrade between or during waves, preview the next threats, and start each wave when ready.

Victories unlock the next level. Earn up to three medals by protecting the flame, and replay levels to improve your best result. Campaign checkpoints and medals save locally, separately from sandbox games. Interrupted waves resume from their preparation checkpoint. See [the campaign guide](docs/CAMPAIGN.md) for all 20 missions, controls and save behavior.

## Developer Controls

Open **Settings → Developer Controls**, choose **Bosses**, **Rifts**, **Enemies**, **Towers**, or **Gear** from the category list, then select a type in its editor. Use **Back to categories** to choose another group. Enemy controls include all six types, including Abyss Shades and Crypt Sentinels, with health, speed, gold reward and knockback resistance. Bosses also expose their defenses, counter strengths, timers, and summon settings.

Typed numbers apply when you press Enter, switch types or categories, go back, or close the panel. A full-health Hollow changed from 45 HP to 400 HP immediately has 400 HP; damaged enemies keep their remaining health percentage, and rift bonuses still apply. Turn on **Show enemy and boss health** to see current / maximum HP on the battlefield during this session. Gear exposes every relic's effect strength, cadence, and duration; equipped relics use changes on their next attack. Existing root cooldowns retain their remaining proportion, while shots already in flight retain their launch damage.

For towers, choose **Tier 1**, **Tier 2**, **Tier 3**, or either **Tier 4 specialization**. Each tier has independent damage, attack interval, reach, cost, blast radius and target count. Specializations also expose slow strength/duration, volley count/spread, burn damage/duration, knockback, fragment count/reach/damage, curse limits/strength, chain reach/damage, or seal and stun settings. Type an exact number or use the plus/minus buttons on the right. Labels and row dividers leave room to scroll without changing values. Costs apply to the selected build or upgrade and flow through refunds and relocation prices. Multiple projectiles can each apply their configured blast.

Changes apply live and save with progress. Health and cooldown adjustments preserve remaining proportions; newly applied ability effects use the edited settings. **Reset selected type / tier** clears only that selection; **Reset all balance values** restores the defaults without resetting progress. Legacy base overrides still load with their original scaling; editing tier 1 preserves sibling tiers. Rift effects are unchanged.

The editor shows factory defaults alongside current values. Offline income learns from new combat after a balance change, while previously earned gold remains available.

## Project layout

| Location | Purpose |
| --- | --- |
| `scenes/` | Entry scene |
| `scripts/app/` | Application lifecycle, saving, UI composition |
| `scripts/gameplay/` | Shared state and balance API |
| `scripts/gameplay/combat/` | Simulation, targeting, projectiles, abilities and enemy indexing |
| `scripts/gameplay/encounters/` | Boss encounters and patrol behavior |
| `scripts/gameplay/progression/` | Economy, tower transactions and relic equipment |
| `scripts/persistence/` | Save validation, checksums, recovery and writes |
| `scripts/world/` | Territory generation, roads, routes and sockets |
| `scripts/ui/` | HUD and navigation panels; `towers/`, `developer/`, and `shared/` own focused UI |
| `scripts/rendering/` | Battlefield composition; `terrain/`, `actors/`, and `effects/` own drawing |
| `tools/` | Source-structure checks and asset authoring utilities |
| `tests/unit/` | Headless gameplay, persistence, input and stress checks |
| `tests/rendered/` | Native GPU and mouse/touch integration checks |
| `tests/previews/` | Disposable terrain preview |
| `tests/support/` | Test timeout support |
| `docs/` | Architecture, art direction and review notes |
| `artifacts/` | Generated logs, reports and screenshots; ignored by Git/export |
| `.godot/` | Regenerable engine cache; ignored by Git |
| `.runtime/` | Local player data, separate test data and recovery archive |

Keep GDScript `.uid` files with their scripts when moving or committing them. Commit source files, `project.godot`, scene files and export presets; generated caches and test output stay out of source control.

## Verify

Run `python3 tools/check_structure.py` after moving source files. It checks resource paths, UID collisions and gameplay imports of presentation code. Engine import and the suites below remain necessary to verify GDScript and behavior.

```powershell
./launch.ps1 -Tests           # Headless gameplay and persistence
./launch.ps1 -Smoke           # Native UI, mouse/touch, camera and lifecycle
./launch.ps1 -StyleTests      # Every screen at three sizes and three text scales
./launch.ps1 -MobileTests     # Touch navigation, scrolling, dropdowns, maps and phone layouts
./launch.ps1 -TerrainTests    # GPU palette, roads, boundaries and world grid
./launch.ps1 -ArtSmoke        # Artwork interactions at two screen sizes
./launch.ps1 -TerrainPreview  # Disposable terrain screenshots
./launch.ps1 -Check           # All automated suites above (except previews)
```

Choose one mode per invocation. `-Import` only imports and validates project resources. The launcher checks script compilation and engine logs as well as exit status, so script errors cannot silently appear successful. The known sandbox certificate-store error is exempted from offline smoke checks; cloud sign-in and sync still require working HTTPS certificates.

See [test coverage](tests/README.md), [architecture and extension guidance](docs/ARCHITECTURE.md), [art direction](docs/ART_DIRECTION.md), and [review results](docs/REVIEW.md).

## Release status

This is a working local prototype with automated desktop coverage. On September 4, 2026, a native release build was signed, installed and launched on an iPhone 16 Pro. Windows, Android and iOS export presets are included. The [iPhone setup guide](IPHONE_SETUP.md) records the installed build, signing expiration, verification and rebuild steps. Broader physical-phone gesture, suspend/resume, battery and large-world performance testing remains appropriate before a public release.

Git was initialized during concurrent setup work, with an initial commit and the `Hollow-Vigil` GitHub remote. Ignore rules, line-ending rules and editor settings are included. No CI configuration was found during this review.

## Optional cloud saves

Settings → Account connects to the Hollow Vigil Supabase project. Gameplay and local saves work offline. Signed-in devices automatically protect all six saved-game slots and the private My builds library; Backups also offers **Back up now**. Complete saved games include progress, custom rules, towers and equipment. Conflicting versions require an explicit player choice. See [cloud save design and setup](docs/CLOUD_SAVES.md) for storage, recovery and verification.


### Saved games and reusable builds

Campaign and Infinite open the same Game home: **Continue**, **New game**, **My builds** and **Community**, with **Backups** and **Settings** below. Each game type has exactly three playable slots. New game chooses Creative or Survival, a starting build, then a named destination and review. Replacing an occupied slot requires confirmation and retains a recovery copy in Backups. Continue opens the matching three-slot list. An unfinished Campaign restarts its saved wave from that wave's starting resources, towers and equipment.

During play, both games use the same Pause, Speed and Menu controls. Menu holds the live session; Resume game returns to it without restarting a wave. Creative **Edit rules** uses a draft with Apply changes and Cancel. **Save build** is a separate form with individual Enemies, Bosses, Towers, Gear and other applicable groups; categories expand to individual registered types. Map, layout, resources and Campaign wave groups remain independently selectable. Campaign scope is Whole campaign or This level. Omitted contents use original defaults, and compatible stats can travel between game types with explicit level choices. Builds always start a new game and never import Campaign unlocks.

The shared form offers **Save privately** and **Share to Community** together. Sharing keeps a private copy, preserves the prepared form through sign-in and player-name entry, and offers an explicit Retry after failure. Community supports browsing, details, Save privately and Use build. Saving or downloading a build does not occupy a playable slot. Players use friendly names and contents summaries; configuration files and codes remain internal. See the [complete menu tree](docs/UI_MENU_TREE.md) and [reusable node guide](docs/NODE_SYSTEM.md).

## Cloud acceptance testing

Run `./launch.ps1 -UnifiedTests` for build composition, complete saved-game persistence, private-backup service behavior and native menu workflows at three phone sizes. `tests/unified_cloud_contracts.sql` checks the deployed APIs under real database roles inside a rolled-back transaction. These checks do not replace a physical second-device or email-delivery test.

The older `tools/cloud_qa.py` utility exercises the legacy world API with a separate QA save library. It uses normal Supabase password authentication for a dedicated, pre-verified test account. Its credentials are configured outside the repository at `~/.config/hollow-vigil/qa-account.json`; no QA login or credentials are included in exported games. This utility does not validate the new complete Campaign backup flow.

See `docs/CLOUD_ACCEPTANCE_2026-09-06.md` for the findings and `tests/README.md` for repeatable database, API and UI checks.
