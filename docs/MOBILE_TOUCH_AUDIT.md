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
| Shared touch behavior | Swipe over cards/buttons, tap versus drag, dropdown selection, nested scrolling, cancellation, modal shielding, pan/pinch, safe-area coordinate conversion and rotation | `touch_scroll_scope_runner`, `mobile_navigation_runner`, `mobile_scroll_runner`, `illustrated_picker_touch_runner` |

The main reachability audit uses 360×640, 390×844 and 540×960 upright portrait viewports. Full menu workflows and rendered screenshots complement checks of bounds: an element existing or receiving a directly emitted signal alone is not evidence of a successful finger interaction. Text and network responses use deterministic fixtures where native keyboards or services are unavailable.

## Repairs

- Nested Back actions return through Campaign wave/build menus and tower equipment menus instead of dismissing the entire interaction. Android Back follows the visible Campaign navigation.
- Equipment removal uses the shared 48-unit screen-control minimum.
- Illustrated choice popups refit to the viewport safe area when orientation changes.
- Mouse emulation from physical touch is explicit in the project configuration, preserving Godot control taps alongside the battlefield's native touch handling.
- Form errors/status are revealed after scrolling settles, so pressing a pinned footer action cannot leave its response offscreen. Navigation revisions prevent an old response from scrolling a later page.
- Stale menu expectations and unusable test helpers were corrected; the launcher includes the additional touch regressions.

## Validation and release boundary

Run `./launch.ps1 -MobileTests` for the touch suites and `./launch.ps1 -StyleTests` for rendered layout coverage. Results from this audit are recorded below after the final runs.

Physical iOS and Android validation remains required for display density, native text keyboards, safe areas reported by the OS, edge/back gestures, interruption/resume, and device performance. The intended native keyboard overlay policy is preserved. World-anchored tower controls continue to scale with their towers as required by the style guide. No real account was signed in and no cloud record was published, replaced or deleted by the touch fixtures. A passing desktop audit cannot guarantee that every future phone session is free of issues; the delivered source must still be built and installed on the phone.
