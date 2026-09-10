# Hollow Vigil

A portrait Campaign tower-defense game built with Godot 4.7.2 and GDScript.

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

Choose **Campaign**, then create or continue one of three saved games. Creative and Survival share those slots. The campaign contains 30 authored levels across six chapters, with a boss at the end of each chapter.

Place towers on open ground beside the roads. Upgrade through three levels, then choose a permanent level-four specialization. Towers share targeting, equipment, sale and relocation controls. Gold is collected automatically. Review enemies in Waves and start each wave when ready; escaped enemies reduce core integrity.

Survival unlocks levels through victories. Creative provides access to all levels and editable rules. Each level starts with its configured resources. Campaign saves retain completed progression, map selection, equipment and custom rules. Leaving an unfinished level starts a fresh attempt on reentry.

Drag to pan and pinch to zoom. The app stays upright in portrait on iOS and Android. Use the in-game Menu to save builds, manage backups, adjust sound, or exit. See [Campaign](docs/CAMPAIGN.md), [tower balance](docs/TOWER_BALANCE.md) and [menu navigation](docs/UI_MENU_TREE.md).

## Creative authoring

Use **Menu → Edit rules** for shared content rules and each level's starting resources. Use **Waves** to edit the selected wave. Changes remain a draft until Apply changes. My builds stores reusable Campaign rules; Community sharing is an explicit action.

## Project layout

- `scripts/app/`: Campaign application and navigation services.
- `scripts/campaign/`: authored levels, wave simulation, progress, map and battlefield.
- `scripts/content/`: reusable definitions and attachable components.
- `scripts/gameplay/`: shared combat, targeting, tower and equipment rules.
- `scripts/ui/`, `scripts/rendering/`, `scripts/audio/`: presentation and interaction.
- `scripts/persistence/`, `scripts/cloud/`: Campaign saves, reusable builds and account services.
- `tests/`: current Campaign and shared-system checks.

## Verify

```powershell
./launch.ps1 -Tests
./launch.ps1 -UnifiedTests
./launch.ps1 -MobileTests
./launch.ps1 -Check
```

Validation uses isolated test data. Rendered checks use upright portrait sizes 360×640, 390×844 and 540×960. Physical iOS and Android acceptance is separate from desktop simulation.

## Account services

Campaign slots and My builds save locally. Sign in for automatic private backups and explicit Community sharing. Existing server data is preserved. See [cloud saves](docs/CLOUD_SAVES.md) for the current client contract. Client configuration is in `supabase/client.cfg`; keep credentials and player saves out of Git.
