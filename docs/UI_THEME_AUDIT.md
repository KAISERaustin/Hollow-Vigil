# Moonlit UI implementation and review

September 16, 2026 · UI theme 3.1

The shared runtime uses charcoal-green foundations, opaque iron panels, recessed
fields, warm text and quiet neutral grain. World scenery and content portraits
retain their authored colors. Main-menu Settings is a secondary action; Campaign
uses the primary action style.

Settings → Button colors offers Moonlit Iron, Ashen Steel, Dusk Violet and Ember
Bronze. The chosen palette updates existing button resources immediately and is
saved in device preferences. Primary/secondary fills vary; destructive and disabled
meanings remain consistent. Buttons use 2-unit black rims in every state. Panels,
cards, fields, badges and row dividers retain 3-unit black rims/lines.

## Coverage

`tests/rendered/moonlit_theme_runner.gd` visits 244 states at each of 360×640,
390×844 and 540×960 (732 renders). It checks the actual control tree's text colors,
surface roles and normal/hover/pressed/selected/disabled button styling. Native
world artwork is excluded from UI palette assertions.

| Menu family | Rendered coverage |
| --- | --- |
| Entry and saved games | Main menu, Campaign home, occupied/empty slots, play style, starting build, review, save-slot picker |
| Settings | Settings, all four button palettes, Sound and its lower rows, sign-in and profile forms, Bug report, Change log |
| Builds and recovery | My builds, build form, scope and level pickers, details, Community offline/entry/details fixtures, Backups and lower rows, restore destination/conflict, deletion confirmation |
| Campaign | Six map chapters, briefing, battle toolbar/HUD/build strip, in-game menu, exit confirmation, victory and defeat |
| Waves | Overview, balancing details, wave editor, enemy quantities, add-enemy choices, reset/new/remove confirmations |
| Rules | All enemy and boss item/Stats pages; all eight tower families and their tiers/specializations, tier pickers and Add Stat pages; all 30 level item/Stats pages |
| Tower management | Information, upgrade confirmation, targeting and selected state, sell and move |

Representative full screenshots and contact sheets were visually reviewed at all
three portrait sizes. Captures remain under ignored `artifacts/` using the
`moonlit-<width>x<height>-<state>.png` prefix. The review found and corrected the
Campaign navigation's old terrain-colored header and modal scrim layering.

## Validation

| Runner | Result |
| --- | --- |
| Moonlit theme | 92,709 checks; 732 rendered states; zero failures |
| Button colors | 1,566 checks; zero failures; real touch selection, live resource updates, disk preference reload, border/contrast checks and rendered scrim layering |
| Menu scrolling | 415 checks; zero failures; top/bottom reachability and page rebuilds |
| Shared surface corners | 960 checks; zero failures; opaque palette fills, rounded edges and no bleeding at multiple scales |
| Welcome layout | Zero failures |
| Campaign navigation | 331 checks; zero failures |
| Stats editor | 156 checks; zero failures |
| Rules navigation / Back | 551 / 774 checks; zero failures |
| Wave editor touch | 198 checks; zero failures |
| Mobile Campaign controls | 1,334 checks; zero failures; 30 levels and three portrait sizes |
| Illustrated picker touch | 261 checks; zero failures, rerun after modal presentation changes |
| Save-slot picker | 9 checks; zero failures |
| Campaign map | 1,331 checks; zero failures; scenery clearance, all destinations, fixed navigation and save-state markers |
| Source loading / structure | 242 scripts load; zero source or resource-boundary failures |

Cloud/account content uses isolated local fixtures; the audit publishes nothing.
These are desktop-rendered and simulated-touch results. Physical iOS/Android
release acceptance has not been performed. The Windows host reports its existing
root-certificate-store warning; the launcher separately checks script and engine
errors and never treats that warning as physical-device evidence.
