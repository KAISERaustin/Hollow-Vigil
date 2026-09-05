# Hollow Vigil

A portrait idle tower-defense game built with Godot 4.7.2 and GDScript.

## Run

Open `project.godot` in Godot and press **F5**, or use PowerShell:

```powershell
./launch.ps1
./launch.ps1 -Editor
```

The launcher accepts `-GodotPath C:\path\to\godot.exe`, then checks `GODOT_PATH`, then Godot on PATH. It also retains the original Downloads installation as a fallback. Use the console executable on Windows. It imports resources before running so a fresh checkout does not depend on an existing `.godot` cache.

Player saves launched this way remain in `.runtime/Roaming/Godot/app_userdata/Hollow Vigil/`. Opening the project directly uses Godot's normal per-user save directory. Test runs use a separate `.runtime/tests/` directory. Do not delete `.runtime` as a whole: it contains player progress.

## Play

- New games start with **280 gold**, an empty core territory, and no enemies. Buy connected territory for **100 gold** to open the first rift. The first Ashneedle costs **60 gold**.
- Buy towers in stone sockets, collect their earnings, upgrade them, and expand. The three tower types trade attack speed, damage, range, and splash radius.
- Every purchased territory continuously spawns enemies. All enemies follow connected roads to the core; escapes cause no damage or gold loss.
- Select a tower to collect its stored gold and reveal Info, Upgrade, and Sell. Sale refunds half its build and upgrade costs plus stored gold. Confirmations guard against duplicate purchases.
- Drag to pan and use the mouse wheel or pinch to zoom. Tower action buttons and gold badges scale with their tower. The Info button opens the field guide; settings include power saving, reset, and return to the core.
- Offline rewards use 80% of demonstrated production, capped at seven days. Rewards never purchase anything or inflate lifetime kill counts.

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
./launch.ps1 -TerrainTests    # GPU palette, roads, boundaries and world grid
./launch.ps1 -ArtSmoke        # Artwork interactions at two screen sizes
./launch.ps1 -TerrainPreview  # Disposable terrain screenshots
./launch.ps1 -Check           # All automated suites above (except previews)
```

Choose one mode per invocation. `-Import` only imports and validates project resources. The launcher checks script compilation and engine logs as well as exit status, so script errors cannot silently appear successful. The known sandbox certificate-store error is exempted; the game uses no network services.

See [test coverage](tests/README.md), [architecture and extension guidance](docs/ARCHITECTURE.md), [art direction](docs/ART_DIRECTION.md), and [review results](docs/REVIEW.md).

## Release status

This is a working local prototype with automated desktop coverage. Windows, Android and iOS export presets are included. The separate [iPhone setup guide](IPHONE_SETUP.md) covers the native iOS handoff. A distributable build still requires matching Godot export templates; Android also requires its build tools and signing configuration. Physical-phone touch, safe areas, suspend/resume, battery use and large-world performance need device testing before release.

Git was initialized during concurrent setup work, with an initial commit and the `Hollow-Vigil` GitHub remote. Ignore rules, line-ending rules and editor settings are included. No CI configuration was found during this review.
