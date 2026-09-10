# Campaign mobile validation

Supported app viewports are upright portrait: 360×640, 390×844 and 540×960. Keep fixed Back/title headers, reachable scrolling content, 48-unit touch targets, safe-area padding and clear ownership of taps and drags.

`launch.ps1 -MobileTests` runs the current main-menu layout, Campaign navigation, full Campaign touch controls and illustrated-picker touch checks. The navigation tests cover entering/leaving levels, canceling exit, menu pause/resume, Creative and Survival, and preserving completed progression. Touch controls cover Campaign menus, placement, tower management, upgrades, waves and scrolling.

`tests/campaign_only_runner.gd` additionally checks startup, slot creation/continue, Campaign build compatibility, backup enumeration, unsupported restore rejection and independent sound preferences.

These are simulated desktop touch checks. Physical release acceptance must confirm iPhone and Android touch, safe areas, keyboard dismissal, interruptions, performance and that turning the device leaves gameplay upright.

September 9, 2026 Campaign validation: 1,415 mobile-control checks, 265 navigation checks and 261 illustrated-picker checks passed across the three portrait sizes; the opening-page layout also passed.
