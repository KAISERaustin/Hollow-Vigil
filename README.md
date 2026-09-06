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
- Buy towers in stone sockets, collect their earnings, upgrade them, and expand. Every tower starts at **level 1** and can upgrade twice, to **level 3**. Ashneedle upgrades cost **60 / 100 gold**, Pyre **120 / 200**, and Obelisk **140 / 220**. See the [tower balance tables](docs/TOWER_BALANCE.md) for all three tiers and total investment.
- Every purchased territory continuously spawns enemies. All enemies follow connected roads to the core; escapes cause no damage or gold loss.
- Select a tower to collect its stored gold and reveal Info, Upgrade, Sell, Move, and Target (the crosshair). Tap Upgrade once to replace its arrows with a check mark, then tap the check mark to upgrade immediately without a pop-up. Selecting another tower or action cancels the pending confirmation. Sale refunds half its build and upgrade costs plus stored gold.
- Target lets each tower choose **First** (least road distance remaining to the core), **Last** (most road distance remaining), or **Most HP** (highest current health). Only enemies in range are eligible. First is the default, including for older saves. Select a mode and Apply targeting to save it for that tower. Equal HP prefers First, with exact ties resolved by spawn order. Moving or upgrading retains the setting.
- Move shows the relocation price and rebuild time before you choose a destination. Tap a highlighted empty socket in any owned territory to pay 20% of the tower's current build and upgrade value (rounded up). Cancel before placement costs nothing. The tower keeps its level and stored gold, frees its old socket, and cannot fire, upgrade, or move again while rebuilding. A scaffold and countdown mark construction; time away also counts. Base rebuilds take 30 seconds for Ashneedle, 60 for Pyre, and 80 for Obelisk, plus 15 seconds per purchased upgrade, with a 180-second cap. Developer build-cost changes also scale the relocation price and base rebuild time.
- Drag to pan and use the mouse wheel or pinch to zoom the map. The HUD keeps a fixed screen size. Tower action buttons stay attached to their towers with a fixed map-space size and spacing, scaling together with the map. Gold badges sit above their towers in map space: their text, borders, spacing, and touch padding scale together with the tower, without independent enlargement. The Info button opens the field guide. Settings include power saving, 100/125/150% text size, reduced motion, reset, and return to the core.
- Offline rewards use 80% of demonstrated production, capped at seven days. Rewards never purchase anything or inflate lifetime kill counts.

## Developer Controls

Open **Settings → Developer Controls**, choose **Enemies** or **Towers**, then select a type. Sliders adjust every enemy's health, movement speed and gold reward, and every tower's base damage, attack interval, reach, build cost and blast radius. Changes take effect live and save with your progress. Lower attack intervals mean faster attacks; a blast radius of zero makes a tower hit one target. Upgrades scale from the adjusted base stats, and build cost also scales upgrade prices and refunds.

The editor shows each default value. **Reset selected type** restores only that enemy or tower; **Reset all balance values** restores the original balance without clearing progress. Existing enemies retain their remaining health percentage. Offline income learns from new combat after a balance change, while previously earned gold remains available.

## Project layout

| Location | Purpose |
| --- | --- |
| `scenes/` | Entry scene |
| `scripts/app/` | Application lifecycle, saving, UI composition |
| `scripts/model/` | Balance, state, economy, combat |
| `scripts/persistence/` | Save validation, checksums, recovery and writes |
| `scripts/world/` | Territory generation, roads, routes and sockets |
| `scripts/ui/` | HUD, panels, dialogs, guide and shared styling |
| `scripts/rendering/` | Battlefield, cached terrain and cosmetic drawing |
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

```powershell
./launch.ps1 -Tests           # Headless gameplay and persistence
./launch.ps1 -Smoke           # Native UI, mouse/touch, camera and lifecycle
./launch.ps1 -StyleTests      # Every screen at three sizes and three text scales
./launch.ps1 -TerrainTests    # GPU palette, roads, boundaries and world grid
./launch.ps1 -ArtSmoke        # Artwork interactions at two screen sizes
./launch.ps1 -TerrainPreview  # Disposable terrain screenshots
./launch.ps1 -Check           # All automated suites above (except previews)
```

Choose one mode per invocation. `-Import` only imports and validates project resources. The launcher checks script compilation and engine logs as well as exit status, so script errors cannot silently appear successful. The known sandbox certificate-store error is exempted; the game uses no network services.

See [test coverage](tests/README.md), [architecture and extension guidance](docs/ARCHITECTURE.md), [art direction](docs/ART_DIRECTION.md), and [review results](docs/REVIEW.md).

## Release status

This is a working local prototype with automated desktop coverage. On September 4, 2026, a native release build was signed, installed and launched on an iPhone 16 Pro. Windows, Android and iOS export presets are included. The [iPhone setup guide](IPHONE_SETUP.md) records the installed build, signing expiration, verification and rebuild steps. Broader physical-phone gesture, suspend/resume, battery and large-world performance testing remains appropriate before a public release.

Git was initialized during concurrent setup work, with an initial commit and the `Hollow-Vigil` GitHub remote. Ignore rules, line-ending rules and editor settings are included. No CI configuration was found during this review.
