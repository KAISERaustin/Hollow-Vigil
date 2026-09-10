# Campaign architecture

Hollow Vigil has 30 authored Campaign levels across six chapters. Creative and Survival share three saved-game slots. The application shell owns navigation, account services and sound preferences. It does not run a background battle.

## Content and simulation

`scripts/content/registry.gd` owns reusable definitions. Towers, enemies, bosses, gear, levels, waves, targeting, projectiles and attachable attributes provide common rules with per-type configuration. Runtime timers, effects and mutable state belong to each instance. See [NODE_SYSTEM.md](NODE_SYSTEM.md).

`campaign/run.gd` owns authored wave scheduling and mission outcomes. `gameplay/combat/` handles enemies, targeting, attacks, component effects and route-distance caches. `gameplay/progression/economy.gd` owns tower purchases, upgrades, sale, relocation and equipment. Campaign supplies placement roads and bounds. Simulation remains independent of drawing and camera visibility.

`world/world.gd` provides coordinate conversion and stable ground-placement keys. Legacy socket keys remain readable. Authored roads determine movement; chapter definitions determine the environment and portal effects.

## Presentation and input

`campaign/board.gd` supplies the authored map, scenery and selection. `rendering/battlefield.gd` supplies shared actor drawing, camera gestures and effects. Tower menus, placement and equipment use shared components in `ui/`. Follow [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md) and [ART_DIRECTION.md](ART_DIRECTION.md).

The main menu offers Campaign and Settings. The game menu pauses the held Campaign session and restores its prior pause state on resume. Full-page headers and actions frame scrolling content. Android Back follows the active navigation owner. All app layouts are upright portrait.

## Persistence and account boundaries

Campaign saves preserve completed levels, current map selection, equipment and authored rules. Leaving an unfinished level starts a fresh attempt on reentry, following the current gameplay policy. Legacy checkpoint validation remains available for older saved payloads. Checksummed storage validates before writes and preserves recovery candidates.

`persistence/reusable_build.gd` composes Campaign rules into new games. `persistence/save_slots.gd` stores the private build library; `campaign_slots.gd` owns playable Campaign slots. Unsupported build types are rejected. Sound preferences live independently in `vigil-preferences.cfg`.

Account credentials belong to `cloud/session_store.gd`. Private backups enumerate only Campaign slots, filter remote listings, validate restores and synchronize compatible private builds. Community publication remains explicit. See [CLOUD_SAVES.md](CLOUD_SAVES.md).

## Validation

Use `launch.ps1 -Check` for the supported Campaign, account, portrait navigation, touch and artwork suites. `tools/check_structure.py` checks resource links, script identities and dependency boundaries. Physical device acceptance is separate from desktop tests.
