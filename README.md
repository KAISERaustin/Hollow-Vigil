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
- Every purchased territory continuously spawns enemies. All enemies follow connected roads to the core; escapes cause no damage or gold loss.
- Select a tower to collect its stored gold and reveal Info, Upgrade, Sell, Move, and Target (the crosshair). At levels 1 and 2, tap Upgrade once to show a check mark, then tap again to upgrade. At level 3, preview and confirm a specialization instead. Selecting another tower or action cancels the pending confirmation. Sale refunds half its build and upgrade costs plus stored gold.
- Target lets each tower choose **First** (least road distance remaining to the core), **Last** (most road distance remaining), or **Most HP** (highest current health). Only enemies in range are eligible. Most HP locks its primary target until that enemy dies or leaves range, then chooses the highest-health enemy still in range. Taking damage or a healthier enemy arriving does not change the lock. Splash and multi-target attacks retain their secondary hits. First is the default, including for older saves. Select a mode and Apply targeting to save it for that tower. Equal HP prefers First on acquisition, with exact ties resolved by spawn order. Moving or upgrading retains the setting.
- Move shows the relocation price and rebuild time before you choose a destination. Tap a highlighted empty socket in any owned territory to pay 20% of the tower's current build and upgrade value (rounded up). Cancel before placement costs nothing. The tower keeps its level and stored gold, frees its old socket, and cannot fire, upgrade, or move again while rebuilding. A scaffold and countdown mark construction; time away also counts. Base rebuilds take 30 seconds for Ashneedle, 60 for Pyre, and 80 for Obelisk, plus 15 seconds per purchased upgrade, with a 180-second cap. Developer build-cost changes also scale the relocation price and base rebuild time.
- Drag to pan and use the mouse wheel or pinch to zoom the map. The HUD keeps a fixed screen size. Tower action buttons stay attached to their towers with a fixed map-space size and spacing, scaling together with the map. Gold badges sit above their towers in map space: their text, borders, spacing, and touch padding scale together with the tower, without independent enlargement. Settings include developer controls and reset; use the header’s X button to close the menu. The game uses a fixed 60 FPS cap, standard text size, and normal motion.
- Offline rewards use 80% of demonstrated production, capped at seven days. Rewards never purchase anything or inflate lifetime kill counts.

Castle ruin tiles can be purchased through connected expansion at the normal territory price. Each becomes a paved tile with four tower sockets and a dark central dungeon portal. Only these portals spawn **Abyss Shades** (240 HP, 56 speed, 30 gold) and **Crypt Sentinels** (680 HP, 28 speed, 55 gold), both available immediately. Traffic upgrades increase their spawn rate. Existing boss encounters keep their progress when a ruin is claimed.

Stone clusters hide one boss each. Buying its assigned tile awakens it;
it patrols owned roads while avoiding the core, escaping only if the core is
its sole exit. Health and encounter
progress survive reloads, and each boss has a level-four tower weakness and
a one-time bounty. See [boss encounters and counters](docs/BOSSES.md).

Bosses also drop **relic equipment**. Select a tower and use the diamond button at the upper left of its action circle to equip, remove, or transfer a relic for free. Every tower has one slot; equipped towers display a matching boss emblem. Selling keeps the item, and older saves receive drops for recorded victories. See [boss relics and their effects](docs/RELICS.md).

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

Settings → Cloud saves connects to the Hollow Vigil Supabase project. Gameplay and local saves work offline. Cloud backup stores only allowlisted progress and reconstruction data; game assets, source code, transient enemies, camera state and developer settings stay local. New content uses stable type keys without a database redesign. See [cloud save design and setup](docs/CLOUD_SAVES.md) for the data boundary, sign-in limitations and verification commands.


### Save slots and custom setups

The game opens with three local save slots. Choose Creative or Survival when creating each save. Existing progress appears in slot 1 as Creative. Creative exposes Developer Controls; Survival blocks gold grants, rule edits and unrestricted camera controls. Settings → Your saves switches slots after saving. Archive and free slot keeps the old files locally while making room for a new save.

In Creative, Settings → Save configuration lets you name a configuration, describe your changes, and save it directly to a local library. It includes the world, towers, resources and tuned values. To reuse one, open an empty save, choose a saved configuration from the scrollable library, select **Creative or Survival**, and press **Create** at the bottom. You can also start with a fresh world. Creative worlds remain editable; Survival worlds keep the chosen rules locked. Configurations receive no offline earnings for time since capture. Cloud identities and personal preferences are excluded. Saving the same name again keeps a separate copy. Resetting Survival progress retains its custom rules. Saves and configurations are local to the device; the existing cloud service still requires default balance values. Sound controls are under Settings → Sound.

Public Builds: Saving a Creative configuration automatically queues it for public upload. Sign in and set your player name under Account & cloud saves to publish; offline uploads retry every minute. Settings → Public Builds and the save creation menu show shared titles, descriptions, author names at publication, and export timestamps in UTC. Choose a build, an empty save slot, and Creative or Survival. Existing saves are preserved. Builds include world layout, resources, towers, equipment and tuning, but omit cloud identity and personal settings.
