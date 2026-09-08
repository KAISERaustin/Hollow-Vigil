# Mobile touch menu audit

September 7, 2026. Scope: the current production menu tree in `UI_MENU_TREE.md`, both game modes, shared contextual menus, and legacy menu components that remain callable. This audit tests source in the Windows Godot runtime using injected `InputEventScreenTouch` and `InputEventScreenDrag`; it does not identify or update an installed phone build.

## Coverage

| Menu family | Surfaces and interactions | Evidence |
| --- | --- | --- |
| Main menu and navigation | Campaign, Infinite, Settings, game home, Back, held-session resume and exit | `mobile_navigation_runner`, `mobile_menu_audit_runner` |
| Saved games and creation | Empty/occupied slots, Continue, delete/replace confirmation, Creative/Survival, starting build, review, name and destination choice | `mobile_menu_audit_runner` |
| Build libraries | My builds, Community, details, use, private save, sharing entry and return, refresh/retry/paging states | `mobile_menu_audit_runner` with an in-memory network fixture |
| Save build | Contents checkboxes, scope/level pickers, name/description, private save, sharing, validation messages and fixed actions | `mobile_navigation_runner`, `mobile_menu_audit_runner` |
| Backups and recovery | Account entry, backup lists, destination, local/cloud comparison, restore/replace/cancel and deletion confirmations | `mobile_menu_audit_runner`; local fixture data only |
| Settings and account | Sound mute, category volumes, numeric entry/step buttons, previews/defaults, email/code/player-name fields, Paste, sign-in return and Done | `mobile_navigation_runner`, `mobile_menu_audit_runner`, `mobile_scroll_runner` |
| Creative rules and tools | Every registered rule category, illustrated type/tier choices, exact values, Apply/Cancel/discard, camera/health toggles, gold action | `mobile_navigation_runner`, `mobile_menu_audit_runner`, `illustrated_picker_touch_runner` |
| Infinite contextual menus | Construction, territory, portals, core, tower information, targeting, equipment, upgrade/branch, sale and relocation | `mobile_navigation_runner`, `mobile_playthrough_runner`, equipment and Campaign shared-tower runners |
| Campaign | Chapter map, level markers, briefing, battle, Waves, wave details/editor, construction, shared tower actions, result navigation | `mobile_playthrough_runner`, `mobile_campaign_controls_runner`, `campaign_upgrade_runner` |
| Shared touch behavior | Swipe over cards/buttons, tap versus drag, dropdown selection, nested scrolling, cancellation, modal shielding, pan/pinch, safe-area coordinate conversion and portrait sizing | `touch_scroll_scope_runner`, `mobile_navigation_runner`, `mobile_scroll_runner`, `illustrated_picker_touch_runner` |

The main reachability audit uses 360×640, 390×844 and 540×960 upright portrait viewports. Full menu workflows and rendered screenshots complement checks of bounds: an element existing or receiving a directly emitted signal alone is not evidence of a successful finger interaction. Text and network responses use deterministic fixtures where native keyboards or services are unavailable.

## Repairs

- Nested Back actions return through Campaign wave/build menus and tower equipment menus instead of dismissing the entire interaction. Android Back follows the visible Campaign navigation.
- Equipment removal uses the shared 48-unit screen-control minimum.
- Illustrated choice popups refit to the viewport safe area when orientation changes.
- Mouse emulation from physical touch is explicit in the project configuration, preserving Godot control taps alongside the battlefield's native touch handling.
- Form errors/status are revealed after scrolling settles, so pressing a pinned footer action cannot leave its response offscreen. Navigation revisions prevent an old response from scrolling a later page.
- Scroll containers refresh their cached content measurements after rebuilding a page. This repairs the zero scroll range reproduced when refreshing the Campaign map with equally tall replacement content.
- Full Campaign build saving no longer repeatedly reconstructs the same validation schemas. Each document still validates every selected value, level and wave. The Save form paints progress before serialization, prevents duplicate taps, and cancels preparation if Back navigates away.
- Stale menu expectations and unusable test helpers were corrected; the launcher includes the additional touch regressions.

## Validation and release boundary

Run `./launch.ps1 -MobileTests` for the touch suites and `./launch.ps1 -StyleTests` for rendered layout coverage. This audit ran the focused touch runners individually and the rendered checks described below; it does not claim the complete repository check passes.

Verified results:

- Shared touch and repeated page rebuilds: 28 checks, 0 failures.
- Mobile navigation after the shared scroll repair: 3,140 checks, 0 failures.
- Illustrated picker: 261 rendered checks, 0 failures.
- Mobile scrolling, legacy menus and numeric controls: 345 rendered checks, 0 failures.
- Campaign upgrades across all 30 levels: 1,200 checks, 0 failures.
- Campaign touch controls: 1,610 checks, 0 failures. All 30 markers were checked at each portrait size and all 30 levels were opened by touch at 390×844.
- Shared equipment UI: 117 checks, 0 failures.
- Long-library finger scrolling and Details/Delete/Cancel: 137 checks, 0 failures.
- Rendered Campaign landscape/map/map-menu/HUD checks: 104 / 2,073 / 627 / 1,581 checks, all passing.
- Parchment corners: 960 checks, 0 failures. Waves: 6,645 checks, 0 failures after correcting a stale test heading from `Level configuration` to `Edit wave 2`.
- UI style: 16 screens at three sizes, 0 failures. Compact menu layout: all developer types at three sizes, 0 failures. Developer layout: 29,757 checks, 0 failures. Portal UI: 168 checks, 0 failures.
- Tuning-schema equivalence and invalid-value coverage: 1,427 checks, 0 failures. Developer tiers: 4,851 checks, 0 failures.
- Unified persistence, all content selections, node extension and final-wave validation: 2,390 checks, 0 failures.

A headless full Campaign build benchmark measured capture / compose / encode / decode at 14,124 / 4,228 / 8,685 / 9,332 ms before the optimization, versus 1,533 / 224 / 508 / 543 ms after it. The encoded document remained 1,952,411 bytes. A native touch Save privately run completed with visible success in 3,067 ms on this PC. These measurements are local observations under concurrent test load, not phone performance guarantees.

The initial navigation test expected Infinite to open the retired home route; it now checks Saved games. The toolbar regression expected identical Campaign and Infinite button coordinates despite their intentionally different compositions; it now verifies reachability, minimum target sizes and non-overlap. Touch workflow fixtures now stop kinetic movement before tapping a specific row, and use valid saved-game data for navigation that requires a successful save.

The three content-to-gameplay imports observed during this audit were subsequently removed by the tower integration work. Line attacks and road traps now call the injected combat owner; `tools/check_structure.py` passes with zero failures. The Windows certificate-store warning appeared in the local test runtime; it is not evidence of a successful device/network test.

Physical iOS and Android validation remains required for display density, native text keyboards, safe areas reported by the OS, edge/back gestures, interruption/resume, and device performance. The intended native keyboard overlay policy is preserved. World-anchored tower controls continue to scale with their towers as required by the style guide. No real account was signed in and no cloud record was published, replaced or deleted by the touch fixtures. A passing desktop audit cannot guarantee that every future phone session is free of issues; the delivered source must still be built and installed on the phone.
