# Moonlit UI implementation and review

September 16, 2026 · UI theme 3.2

The runtime uses charcoal-green foundations, iron panels, recessed fields, warm
text and quiet grain. Fixed action colors coexist in menus: iron for neutral
actions, steel for navigation/information, violet for editing, bronze for
construction/recovery and cloak red for danger. Light aged-metal, silver, rose
and copper fills emphasize commitments. The color selector is removed; old
palette preferences are retired while sound preferences remain intact.

Every UI enclosure and divider uses the same **1-unit black border**.
`BUTTON_OUTLINE` aliases `OUTLINE` so cards and buttons cannot drift apart.
Chapter separators belong to the live UI rather than baked map artwork. World
art retains its own colors and contours. Local launcher runs are muted by default.

## Coverage

`tests/rendered/moonlit_theme_runner.gd` visits 276 states at each of 360×640,
390×844 and 540×960 (828 renders). It follows the current catalog, including all
48 level editors in the concurrent Campaign expansion. It checks actual control
colors and normal/hover/pressed/selected/disabled button styling.

| Menu family | Rendered coverage |
| --- | --- |
| Entry and saved games | Main menu, Campaign home, slots, play style, starting build, review and save-slot picker |
| Settings | Settings, Sound and lower rows, sign-in/profile, Bug report and Change log |
| Builds and recovery | My builds, build forms/pickers/details, Community fixtures, Backups, restore destination/conflict and deletion confirmation |
| Campaign | All six map chapters, briefing, battle toolbar/HUD/build strip, game menu, exit confirmation, victory and defeat |
| Waves | Overview, balancing details, editor, quantities, add-enemy picker, reset/new/remove confirmations |
| Rules | Every enemy/boss item and Stats page; eight tower families with tiers, branches, pickers and Add Stat; every level item and Stats page |
| Towers | Information, upgrade, targeting, sell and move |

Screenshots were visually reviewed at all three portrait sizes, including the
Waves card/button border comparison requested by the user. Captures remain under
ignored `artifacts/` as `moonlit-<width>x<height>-<state>.png`.

## Validation

| Runner | Result |
| --- | --- |
| Complete theme | 112,773 checks; 828 rendered states; zero failures |
| Fixed button roles | 1,644 checks; zero failures; fixed colors, old preference removal, preserved audio preferences, uniform rims, navigation and scrim layering |
| Menu scrolling | 409 checks; zero failures; first/last reachability and rebuilds |
| Surface corners | 960 checks; zero failures; includes one-unit rims, rounded edges and multiple scales |
| Baked map | 165 checks; zero failures; atlas compositing and exact one-unit live separators |
| Wave menus | 6,066 checks; zero failures |
| Welcome / Campaign navigation | Zero failures / 331 checks, zero failures |
| Stats / Rules navigation / Back | 156 / 713 / 936 checks; zero failures |
| Wave editor touch | 198 checks; zero failures |
| Mobile Campaign controls | 1,622 checks; zero failures; every current level and three portrait sizes |
| Illustrated picker / save-slot picker | 261 / 9 checks; zero failures |
| Source loading / structure | 244 scripts load; zero source or resource-boundary failures |

The broad interaction run initially reached an outdated wave-editor fixture that
opened a locked level. Wave and full-menu fixtures now use an explicitly
progressed test save, and the wave fixture selects a current two-road level.
Those runners and the remaining picker checks were rerun silently and passed.
Fresh-save unlock behavior retains its separate progression tests.

Cloud/account pages use isolated fixtures and publish nothing. These are desktop
renders and simulated touch; physical iOS/Android acceptance was not performed.
The host reports its existing root-certificate-store warning. The theme and
mobile-control runners reported two retained objects at shutdown without a
script error or failed assertion.

## September 17 — automatic wave playback

`rendered/auto_wave_runner.gd`: 150 checks, zero failures in an isolated fresh
checkout with Dummy audio. Verified real toolbar taps, manual first wave,
reward dismissal before automatic subsequent waves, pause/menu blocking,
disabling during combat, manual restart, final victory, and per-attempt state
isolation across all 48 levels. Inspected 360×640, 390×844 and 540×960 renders;
Start wave and the On/Off skip toggle stay together with full-size targets.
Structure checks passed. Physical iOS/Android testing was not performed.
The runner intermittently reports the existing two retained objects at shutdown;
no script errors or failed assertions occurred.
