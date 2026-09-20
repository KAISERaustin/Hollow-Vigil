# Campaign verification

Run the smallest runner that covers the changed behavior. The launcher supplies isolated saves, resource import, script preflight, exit-code checks and engine-error scanning even for one test:

```powershell
./launch.ps1 -TestScript tests/campaign_reset_runner.gd -Headless
./launch.ps1 -TestScript tests/rendered/wave_editor_runner.gd
```

Omit `-Headless` for rendering, screenshots and input tests. Each launcher invocation gets its own `.runtime/tests/<run>/` save directory and `artifacts/test-runs/<run>/` logs, printed at startup; simultaneous tasks cannot delete each other's open logs. Screenshot outputs remain under `artifacts/`.

Every launcher mode is silent by default. Only use `-Sound` when the user asks for audible testing. Direct Godot preview commands must include `--audio-driver Dummy`; this leaves player sound preferences intact.

| Changed area | Focused coverage |
| --- | --- |
| Campaign simulation, routes, progression | `campaign_runner.gd`, `campaign_unlocks_runner.gd`, `campaign_expansion_runner.gd`; `campaign_balance_runner.gd` for difficulty changes |
| Content nodes and shared stats | `content_node_runner.gd`, `stats_system_runner.gd`, `tuning_schema_runner.gd`, `simplified_rules_runner.gd` |
| Hex support and portal gameplay | `hex_support_runner.gd`, `portal_attributes_runner.gd` |
| Hex Lantern authored artwork | `rendered/hex_lantern_art_runner.gd` (five source mappings, fixed ground/muzzle, normal/high zoom, portraits, three phone sizes) |
| Moonwheel authored artwork | `rendered/moonwheel_art_runner.gd` (five source mappings, fixed ground/muzzle, outward/return hits, normal/high zoom, compact portraits, three phone sizes) |
| Caltrop Keep authored artwork | `rendered/caltrop_keep_art_runner.gd` (five source mappings, fixed ground/scale, normal/high zoom, portraits, three phone sizes) |
| Waves and exports | `wave_editor_runner.gd`, `campaign_configuration_runner.gd`, `campaign_export_runner.gd` |
| Saves, restart and camera | `campaign_ground_save_runner.gd`, `campaign_reset_runner.gd`, `campaign_camera_runner.gd` |
| Account, backup and reports | `account_session_runner.gd`, `campaign_private_backup_runner.gd`, `bug_reports_runner.gd`; HTTP transport uses `tools/test_account_session_http.py` |
| Stats and rules UI | `rendered/stats_editor_runner.gd`, `rendered/rules_navigation_runner.gd`, `rendered/rules_back_runner.gd` |
| Menus and touch | `rendered/campaign_navigation_runner.gd`, `rendered/mobile_campaign_controls_runner.gd`, `rendered/illustrated_picker_touch_runner.gd`, `touch_scroll_scope_runner.gd`, `reward_input_runner.gd` |
| Waves UI | `rendered/wave_editor_runner.gd`, `rendered/wave_menu_runner.gd` |
| Progression UI | `rendered/campaign_unlocks_runner.gd` (both modes, level locks, tower locks, replay upgrades, three phone sizes) |
| Campaign maps | `rendered/campaign_map_runner.gd`, `rendered/campaign_map_menu_runner.gd`, `rendered/baked_map_runner.gd`, `rendered/campaign_landscape_runner.gd` |
| Terrain and portals | `rendered/campaign_terrain_checks.gd`, `rendered/campaign_portal_runner.gd` |
| Tower presentation | `rendered/tower_depth_runner.gd`, `rendered/tower_level_indicator_runner.gd`, `rendered/tower_upgrade_art_checks.gd`, `rendered/construction_effect_runner.gd`, `rendered/hex_effect_runner.gd` |
| Ashneedle / Gloamwatch authored sprites | `rendered/gloamwatch_runner.gd` (all five approved sources, shared anchor, firing opening, normal/high zoom, export route, portraits, three phone sizes) |
| Stormspire authored sprites and lightning origin | `rendered/stormspire_runner.gd`, `portal_attributes_runner.gd` (all five stages, high zoom, portraits, three phone sizes, primary and chain origins) |
| Complete dark theme and fixed action colors | `rendered/moonlit_theme_runner.gd` (all menus, content types, every level editor, fixed action roles, contrast and borders); `rendered/button_roles_runner.gd` (built-in colors, legacy preference removal, uniform borders, touch navigation and modal layering) |
| Shared surfaces, currency and slots | `rendered/parchment_corner_runner.gd`, `rendered/currency_text_runner.gd`, `rendered/save_slot_picker_runner.gd`, `rendered/welcome_layout_runner.gd` |

Use `-Tests` for the broader Campaign simulation suite, `-UnifiedTests` for application/session/backup checks, and `-MobileTests` for the supported portrait UI suite. `-Smoke` and `-StyleTests` both run welcome layout and Campaign navigation. `-TerrainTests` and `-TerrainPreview` both run the authored Campaign terrain checks. `-ArtSmoke` runs Hex effects and construction effects. `-Check` combines these launcher suites; standalone specialist runners in the table are selected when their feature changes.

## Retired coverage

The September 2026 cleanup removes enemy/boss capability and resistance behavior tests, equipment interaction/effect tests, portal rule-editor tests, old Creative-tools navigation, flat rules-editor assumptions, and obsolete checkpoint-resume expectations. Upgrade effects have one owner, `construction_effect_runner.gd`; tower artwork no longer repeats the old three-level gameplay test.

Historical tower concepts and retained gear artwork are manual generators under `tools/previews/`, outside the test suites and recursive test source loading. They remain available for art reuse. Built-in tower effects and portal gameplay are still active. Old save/tuning validation stays covered while production readers accept those formats; legacy names alone do not make a compatibility test obsolete.

When removing a feature, remove its test cases and launcher/documentation references in the same change. Keep mixed runners' active checks. Do not turn a failure into a pass by skipping a still-supported feature.

Phone UI coverage uses upright portrait sizes 360x640, 390x844 and 540x960. Wide artwork contact sheets are asset inspections. Simulated desktop touch does not establish physical iOS/Android acceptance.

`rendered/auto_wave_runner.gd` checks the skip toggle, manual and automatic wave
starts, reward dismissal, pause/menu blocking, final-wave completion and toolbar
targets at all three portrait sizes, plus playback-state isolation on 48 levels.

`campaign_private_backup_runner.gd` verifies explicit private upload/recovery, no
automatic work at former timer deadlines, no retries, and account isolation.
`rendered/manual_cloud_runner.gd` exercises real Campaign kills, wave transitions,
victory and lifecycle saves, then taps Upload build and download-only recovery at
360x640, 390x844 and 540x960. It uses fake transport and isolated local saves.
