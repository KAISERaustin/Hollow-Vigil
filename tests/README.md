# Campaign verification

Run the smallest runner that covers the changed behavior. The launcher supplies isolated saves, resource import, script preflight, exit-code checks and engine-error scanning even for one test:

```powershell
./launch.ps1 -TestScript tests/campaign_reset_runner.gd -Headless
./launch.ps1 -TestScript tests/rendered/wave_editor_runner.gd
```

Omit `-Headless` for rendering, screenshots and input tests. Each launcher invocation gets its own `.runtime/tests/<run>/` save directory and `artifacts/test-runs/<run>/` logs, printed at startup; simultaneous tasks cannot delete each other's open logs. Screenshot outputs remain under `artifacts/`.

| Changed area | Focused coverage |
| --- | --- |
| Campaign simulation, routes, progression | `campaign_runner.gd`; `campaign_balance_runner.gd` only for difficulty changes |
| Content nodes and shared stats | `content_node_runner.gd`, `stats_system_runner.gd`, `tuning_schema_runner.gd` |
| Hex support and portal gameplay | `hex_support_runner.gd`, `portal_attributes_runner.gd` |
| Waves and exports | `wave_editor_runner.gd`, `campaign_configuration_runner.gd`, `campaign_export_runner.gd` |
| Saves, restart and camera | `campaign_ground_save_runner.gd`, `campaign_reset_runner.gd`, `campaign_camera_runner.gd` |
| Account, backup and reports | `account_session_runner.gd`, `campaign_private_backup_runner.gd`, `bug_reports_runner.gd`; HTTP transport uses `tools/test_account_session_http.py` |
| Stats and rules UI | `rendered/stats_editor_runner.gd`, `rendered/rules_navigation_runner.gd`, `rendered/rules_back_runner.gd` |
| Menus and touch | `rendered/campaign_navigation_runner.gd`, `rendered/mobile_campaign_controls_runner.gd`, `rendered/illustrated_picker_touch_runner.gd`, `touch_scroll_scope_runner.gd`, `reward_input_runner.gd` |
| Waves UI | `rendered/wave_editor_runner.gd`, `rendered/wave_menu_runner.gd` |
| Campaign maps | `rendered/campaign_map_runner.gd`, `rendered/campaign_map_menu_runner.gd`, `rendered/baked_map_runner.gd`, `rendered/campaign_landscape_runner.gd` |
| Terrain and portals | `rendered/campaign_terrain_checks.gd`, `rendered/campaign_portal_runner.gd` |
| Tower presentation | `rendered/tower_depth_runner.gd`, `rendered/tower_level_indicator_runner.gd`, `rendered/tower_upgrade_art_checks.gd`, `rendered/construction_effect_runner.gd`, `rendered/hex_effect_runner.gd` |
| Shared surfaces, currency and slots | `rendered/parchment_corner_runner.gd`, `rendered/currency_text_runner.gd`, `rendered/save_slot_picker_runner.gd`, `rendered/welcome_layout_runner.gd` |

Use `-Tests` for the broader Campaign simulation suite, `-UnifiedTests` for application/session/backup checks, and `-MobileTests` for the supported portrait UI suite. `-Smoke` and `-StyleTests` both run welcome layout and Campaign navigation. `-TerrainTests` and `-TerrainPreview` both run the authored Campaign terrain checks. `-ArtSmoke` runs Hex effects and construction effects. `-Check` combines these launcher suites; standalone specialist runners in the table are selected when their feature changes.

## Retired coverage

The September 2026 cleanup removes enemy/boss capability and resistance behavior tests, equipment interaction/effect tests, portal rule-editor tests, old Creative-tools navigation, flat rules-editor assumptions, and obsolete checkpoint-resume expectations. Upgrade effects have one owner, `construction_effect_runner.gd`; tower artwork no longer repeats the old three-level gameplay test.

Historical tower concepts and retained gear artwork are manual generators under `tools/previews/`, outside the test suites and recursive test source loading. They remain available for art reuse. Built-in tower effects and portal gameplay are still active. Old save/tuning validation stays covered while production readers accept those formats; legacy names alone do not make a compatibility test obsolete.

When removing a feature, remove its test cases and launcher/documentation references in the same change. Keep mixed runners' active checks. Do not turn a failure into a pass by skipping a still-supported feature.

Phone UI coverage uses upright portrait sizes 360x640, 390x844 and 540x960. Wide artwork contact sheets are asset inspections. Simulated desktop touch does not establish physical iOS/Android acceptance.
