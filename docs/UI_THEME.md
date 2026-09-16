# Hollow Vigil UI theme

Pickard · Ink, parchment and moonlit illustration · September 16, 2026

## Read this before creating or changing UI

This is the reusable theme for the UI as it exists today. Use it for every new
screen, feature, option, editor and dialog. Preserve the current visual identity
and touch behavior, including **descriptions on the left, actions on the right,
and a black line between option rows**. This document records the shared design;
it does not authorize adding controls or changing gameplay.

Read this first, then the relevant recipe in [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md).
These documents describe one theme: this file is the implementation reference;
the style guide retains the approved visual reference and expanded design guidance.
Keep them consistent when the user requests an intentional change. Current user
instructions take precedence. [ART_DIRECTION.md](ART_DIRECTION.md) owns artwork;
[UI_MENU_TREE.md](UI_MENU_TREE.md) owns navigation. Older screenshots or unused
controls must not revive removed game features.

## Overall appearance

The opening screen establishes the identity for the whole UI: a moonlit
charcoal-green world, parchment lettering, angular iron and muted red cloth,
strong black structure, a spare diamond motif and warm gold-paper actions.
Readable parchment cards and editors belong to that same world. Quiet paper
texture, compact rectangular shapes and native portraits connect the illustrated
screens to the information screens. Leave the world visible during gameplay;
group related information without unnecessary frames or empty padding.

### One theme, composed in layers

| Layer | Visual language | Where and how to use it |
| --- | --- | --- |
| Illustrated foundation | Charcoal-green moonlit scenery, angular silhouettes, parchment moon, weathered iron and muted red cloth | Welcome composition, Campaign scenery and contextual art; preserve clear areas for live text and controls |
| Reading surfaces | Warm textured parchment, black text, compact cards, uniform ink outlines | Menus, forms, choice lists, rule editors, stat cards and dialogs |
| Identity and actions | Parchment serif display lettering on dark art; diamond ornament; ochre paper buttons with black labels | Major title compositions and deliberate identity accents; the same action treatment continues inside parchment pages |

These are parts of one style, not separate themes or exceptions for the opening
screen. Choose the composition to suit its content: a hero page can expose the
illustrated foundation; a dense editor uses more reading surface. A normal form
does not need a full-screen knight or a diamond on every row to belong to this
theme. Keep decorative marks sparse, non-interactive and clear of descriptions,
touch targets and scrolling. Never put busy art directly behind essential small text.

The opening screen's PICKARD wordmark may use uppercase and spaced lettering;
functional labels retain sentence case. Its generous central artwork space and
bottom actions are the theme's hero-page layout. Compact information screens
use the page and row layouts below. Both share the same material, ink and button
rules. Preserve current compositions while applying this language to future work.

- All visible enclosures and row dividers use **3 UI units of solid black**.
- Rectangular corners are **4 units**; edge-to-edge chrome has square corners.
- No border thickening on press, focus, selection or hover.
- No hover response or tooltip. No decorative shadows, glow, glass, bevels,
  gradients, capsules or continuously pulsing interface elements.
- Passive labels, portraits and row backgrounds remain usable for scrolling.
- Use the shared theme and components, not a separate local interpretation.

All dimensions below are logical UI units. Physical touch size still depends on
device density. Phone layouts stay upright portrait at 360×640, 390×844 and
540×960; respect the notch and home indicator.

## Colors and textures

| Shared role | Color | Use |
| --- | --- | --- |
| `UI.TEXT`, `UI.BORDER` | `#000000` | Main text, borders, dividers and icons |
| `UI.BG`, `UI.MUTED` | `#222A30` | Dark canvas; supporting text on light surfaces |
| `UI.MAIN_MENU_BACKGROUND` | `#192322` | Charcoal-green atmosphere reference for illustrated foundations; existing forest tint token |
| `UI.PANEL` | `#E8DDBD` | Paper cards, sheets, dialogs; inverse text on dark artwork |
| `UI.SURFACE` | `#DFD0AB` | Inset groups, secondary buttons and entry fields |
| `UI.GOLD` | `#E0B568` | Primary actions and purposeful emphasis |
| `UI.DANGER` | `#DB8D73` | Destructive actions and confirmations |
| `UI.SAVED_GAMES_PAPER` | `#B8C4C6` | Saved-games page background, behind parchment cards |
| `UI.ADDED_RULES` | `#95AA83` | Green Added section in applicable rule editors |
| `UI.ADDED_RULE` | `#B49DCC` | Purple card for one added rule or related capability |
| Core illustration | `#93C9BC` | Core identity; not a universal success color |
| Modal scrim | Black at 65% | Inactive scene behind the tower/modal overlay |

Use `UI.box()` / `UI.surface()` and the shared parchment renderer for tan,
gold and coral surfaces. The tan source is `assets/ui/welcome-parchment.png`;
gold and coral use the existing yellow/red paper variants. Green and purple
rule cards retain their shared fills. Do not invent a new texture per screen.
The saved-games background tints the existing paper, keeping its ink frame black.

The opening-page illustration provides varied charcoal-green tones rather than
a flat fill. Its iron grays and muted cloak red are identity colors sampled from
the [Pickard reference](../assets/ui/pickard-reference.jpg), not extra semantic
button colors. Preserve their muted appearance through the art assets instead
of inventing unsupported hex tokens. Biome colors extend the illustrated
foundation while reading surfaces keep their consistent palette. Keep small text
dark on paper; color never replaces labels such as Selected, Off or Delete.
Essential text should meet 4.5:1 contrast and control boundaries 3:1.

## Type and spacing

Use the bundled Noto Sans for labels, numbers and controls; Noto Serif semibold
for large titles. Shared font helpers enable tabular numbers and the currency
glyph. Keep source/accessibility wording meaningful; visible whole-word gold is
rendered by the shared coin presentation. Measure the displayed text.

| Role | Current size and treatment |
| --- | --- |
| Full-page title | 28 in the page shell; large-title helper defaults to 30, serif semibold |
| Object/dialog title | 24, serif semibold |
| Compact title | 22 or 18, sans bold |
| Section heading / ordinary stat value | 18, sans bold |
| Featured value | 24, sans bold |
| Body / button | 16, sans regular / semibold |
| Supporting label / compact action | 14 |
| Metadata | 12 minimum; not for essential action consequences |

Use sentence case, explicit verbs and units. Put bold values above their labels
in stat cells. Descriptions align left and wrap. Do not shrink ordinary text to
force a row to fit. `UI.fitted_heading()` is the existing exception for compact
single-line editor/picker titles, fitting 24 down to 16 with a full accessible name.

| Shared token or layout | Units |
| --- | --- |
| `OUTLINE` / `RADIUS` | 3 / 4 |
| `SCREEN_PADDING` | 12 inside the safe area in the full-page shell |
| `PADDING` | 16 for ordinary surfaces |
| `CARD_PADDING` | 12 |
| `INSET_PADDING`, `CARD_GAP` | 8 |
| `GAP` | 12 between sections and actions |
| Value-to-label gap | 4 |
| `TARGET` | 48 minimum screen-control height; 48×48 icon target |
| Primary page/footer action | 52 high |
| Compact identity portrait | Usually 48; larger detail art uses its existing recipe |

Use the 4-unit spacing scale for new compositions: 4, 8, 12, 16, 24, 32, 48.
Retain existing component exceptions instead of changing them during unrelated
work: the menu content and welcome buttons use 14-unit gaps, form captions use
6, and compact quantity badges can use 6-unit padding. Apply padding once through
the owning surface/container; avoid adding margins on top of equivalent margins.

## Page positions and navigation

```text
Safe top + 12
[ Back ]  Screen title                  [ contextual action, if needed ]
            12-unit gap
┌ Scrolling content ──────────────────────────────────────────────────┐
│ Cards, option rows, fields and explanations                         │
│ Last item remains reachable                                        │
└────────────────────────────────────────────────────────────────────┘
            12-unit gap
[ Primary progression / save action ]
[ Secondary action, when this page needs one ]
Safe bottom + 12
```

The shared full-page shell keeps its header and footer fixed; only the middle
content scrolls. Back is a square arrow at the top left, with an accessible
destination name. The title expands into the remaining width. A contextual
header action or Close sits at the right when required. Do not add a Close
button to pages that only have Back.

Align content to the same left/right inset. Footer buttons follow the page's
existing vertical stack. Keep headers/actions reachable even at the end of a
long list. Opening a different page resets its content scroll. Back, Escape and
Android Back follow the same current route; preserve draft/discard behavior and
the live game's prior pause state. Reuse the protected Back component so one
press cannot accidentally navigate twice.

## Option rows: left information, right control

This is the default for a scrolling list of choices, categories or editable
options. The **row itself is not a button**.

```text
[portrait] Name / setting label                    [ Open / Select ]
           Optional explanation or current state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[portrait] Next name / setting label               [ Open / Select ]
           Optional explanation or current state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. Put the optional portrait at the far left. Let the description expand and
   wrap in the middle. Put the explicit action at the far right, centered vertically.
2. Reuse **`UI.action_row()`**: 12-unit gaps, minimum row height 64,
   minimum action width 88 and action height 48. Illustrated picker and content
   browser rows use 76 minimum. Grow row height for wrapped text.
3. Draw **one 3-unit black divider across the row width below each row**.
   The helper already draws it; do not add a second separator at the same edge.
   Preserve that line for selected and disabled rows. Choice lists use zero
   extra row-container separation so their contents sit between the lines.
4. Keep a consistent trailing action width across a choice list. Reserve enough
   width for both Select and Selected, so selection does not shift the text/art.
5. When an item has several controls, keep them together on the right in a
   compact action group. Preserve at least 8 units between targets, preferably
   12. On narrow screens wrap/stack the right-side group or move it to a
   right-aligned continuation beneath the description; keep each control at
   least 48 high and preserve visual/focus order. Extend the shared row owner
   when needed. Do not scatter buttons across the description's swipe area.
6. Text, artwork and empty space must pass a vertical drag to the list. Selecting
   an item requires tapping its action; dragging must not activate it.

This rule applies to repeated option rows, not every unrelated arrangement.
Existing full-width navigation buttons, fixed footer actions, compact mode tabs,
and the direct save-slot picker remain their own reusable patterns. A framed
passive card already provides separation; do not put a second heavy line under
each line of descriptive text or every stat cell.

### Numeric rows and other fields

Use **`UI.number_row()`**: a wrapping label on the left, optional preview control
before the input, and a centered numeric field on the right. The default input
minimum is 112×48; the row starts at 72 high and grows with its label. Use the
same bottom divider and 12-unit spacing as option rows. Preserve default-value
context where provided by the editor.

Numbers are directly typeable, select all on focus, and request a numeric mobile
keyboard. Keep increment/decrement arrows hidden through the shared helper,
including its empty icon overrides. Do not replace this with tiny plus/minus targets.
Text fields use `UI.style_entry()` and forms use `UI.form_field()` for a caption
above the editor. Toggles show On/Off. Do not intercept text selection, keyboard
input or slider gestures just to make the parent scroll.

## Buttons and states

| Purpose/state | Treatment |
| --- | --- |
| Primary | `UI.gold_button()`, gold paper, black semibold label |
| Secondary | `UI.button()`, inset paper |
| Destructive | `UI.accent_button(..., UI.DANGER)`, coral paper, explicit verb |
| Default | 3-unit black outline, 4-unit corners, at least 48 high |
| Hover | Exactly the resting appearance, including icon tint; no tooltip |
| Pressed | Contents move down 1 unit; hit target and border stay fixed |
| Selected | Explicit state wording/marker; shared toggles draw an underline; use the owning component's selected fill |
| Disabled | Shared inset and muted text, still readable; explanation nearby when needed |
| Keyboard focus | Keyboard navigation retained; no added ring |
| Pending operation | Keep dimensions stable, prevent duplicate activation, show meaningful status |

Allow ordinary button text to wrap and height to grow. Short trailing row actions
stay compact. Task pages have one clear primary action. Hero-page entry choices
use the shared gold treatment, as Campaign and Settings do on the welcome page.
Keep destructive
consequences readable and exact before confirmation. Never make hover necessary.

## Cards, lists and screen recipes

| Surface | Composition to preserve | Reusable owner |
| --- | --- | --- |
| General information | Header/status, divider when needed, values above labels, portrait/name/role/count, then actions | `UI.info_card()`, `UI.stat()`, `UI.rule()`, `content_portrait.gd` |
| Saved games | Separate parchment name and mode cards with 8-unit gap; name wraps, mode is content-sized; progress cells then actions; blue-gray page behind | `saved_game_card.gd` |
| My builds, Community, Backups | Fixed page navigation, scrolling entries/details, visible state/recovery messages; retain Save privately before Share to Community | `unified_menu.gd`, `contents_checklist.gd` |
| Settings, Sound, Account, Bug report, Change log | Same page shell, labeled controls, scrolling forms/notes, inline feedback, stable footer actions | `unified_menu.gd`, `save_slots_panel.gd` |
| Choice popup | Fixed title and top-right Close, header divider, scrollable illustrated rows with right-side Select; selected row revealed on opening | `illustrated_picker.gd` |
| Rules browsing | Category list → item → editing page; native portraits and right-side Open; fixed navigation and draft actions | `rules_browser.gd`, `unified_menu.gd` |
| Stats/rule editing | Inset Default section; where supported, green Added section containing one purple card per added rule, with its heading, related fields and disable control together | `stats_editor.gd`, `UI.rule_card()`, `campaign_level_rules.gd` |
| Waves | Wave title/status, divider, four value cells in four columns at ≥400 available grid units or two below, native enemy roster, trailing quantities and action row | `wave_summary.gd`, `wave_balance.gd` |
| Confirmation | Centered content-sized paper panel, consequence above action, confirm then Cancel; scroll long details while actions stay reachable | `confirmation_popup.gd` |
| Tower details | Compact content-sized panel; identity/portrait header, contextual Back and top-right Close, scrollable details, relevant actions; preserve existing dismissal and placement behavior | `tower_dialog.gd`, `stat_comparison.gd` |

Use the current owner's available controls and model data. Some reusable rule
presentation supports capabilities that are not exposed by the current simplified
Stats-only UI. Do not add retired Abilities/Attributes tabs, equipment flows or
other controls merely because old guide text or reusable code mentions them.

The illustrated choice popup is centered inside its safe viewport with 12-unit
clearance, up to 480 wide and 560 high, constrained by available height. The
existing direct-choice variant is content-sized and uses full-width choices.
The confirmation helper is content-sized, normally up to 380 wide with 16-unit
panel padding. Use the owning component's fitting rules rather than copying
hard-coded screen coordinates.

## Artwork pages and gameplay positions

**Opening screen:** full-bleed, aspect-preserving Pickard art from
`assets/ui/pickard-menu-background.png`. Live parchment PICKARD / THE KNIGHT
text and the diamond ornament sit in the dark sky; the knight, sword, shield and
boots remain visible in the middle. Campaign and Settings are centered over the
dark foreground below him: 56 high, up to 320 wide, 14-unit gap. The artwork
fills the viewport while live controls respect safe areas and remain scrollable
on short screens. Use `welcome_menu.gd` and `welcome_art.gd`; keep text/buttons
out of the image itself.

**Campaign map:** a fixed Back/title header above six edge-to-edge biome sections.
One 3-unit black line separates adjacent chapters. No parchment chapter cards or
gutters. Preserve native destination illustrations, numbered labels, locked/current/
completed states and at least 48-unit destination targets. Labels stay clear of
scenery and route crossings. World art is governed by the art direction guide.

**Battle:** parchment toolbar at the top with Back, Pause, Speed, Waves and Start
wave; terrain fills the remaining viewport. Below the toolbar, one row of three
passive parchment cards shows numbered level identity, currency and wave count.
Keep all three in a row, wrapping their text rather than shrinking it. Their
gestures pass through to the world. `floating_game_hud.gd` owns this arrangement.

The tower build strip sits at the bottom: icon-only squares, at least 48×48,
8-unit gaps, horizontal scrolling and bottom safe-area clearance, without an
extra surrounding panel. Tower-attached actions and earnings badges use their
existing world anchors and scale with towers; screen HUD text does not scale
with camera zoom. Preserve the actual current tower control composition.

## Scrolling, input and feedback

- Attach `UI.keyboard_scroll()` to scrolling lists. It installs the shared
  `touch_scroll.gd` behavior and supports touch, wheel and keyboard while menu
  scrollbar rails stay hidden. Vertical pages disable horizontal scrolling.
- Preserve a continuous passive swipe area through row labels, portraits and
  gaps. Disabled action rows must also scroll. Controls open on a completed tap,
  not on initial touch-down that steals a swipe.
- Keep dynamically added/rebuilt rows attached to the scroll owner. Do not let
  old scroll observers alter controls after they leave that owner. Nested scroll
  areas, text fields and range controls retain their own input behavior.
- Fit popups to the owning safe viewport, not the opener's tiny rectangle.
  Reveal focused/selected content. Closing a picker restores focus to its opener.
- Only the top active modal owns input. Block tap-through to gameplay or the
  underlying page. Retain explicit Cancel/Close and safe Back behavior.
- Keep feedback adjacent to the task; reveal inline errors after a page rebuild
  or footer action. Empty/locked/error states say what happened and the available
  next action. Do not use color alone or invent unavailable loading behavior.
- Preserve the native keyboard's existing overlay behavior without resizing
  the whole menu. Check editing, focus and dismissal separately from scrolling.
- Keep existing restrained motion. No bounce or continuous pulsing; the shared
  earnings badge rises 36 units over 0.95 seconds. Do not add animation just to
  illustrate this theme.

## Implementation and review checklist

The source of reusable tokens and primitives is
[`scripts/ui/shared/interface.gd`](../scripts/ui/shared/interface.gd). Extend a
shared owner before making a local variant. Pass values/actions from the existing
model/service; presentation must not invent balance, save or progression state.

For every new or changed screen:

- [ ] Matches the relevant recipe, colors, texture, fonts and 3-unit borders.
- [ ] Uses the existing page shell, fixed navigation and appropriate action placement.
- [ ] Repeated options have left-side information, right-side controls and one line per row.
- [ ] Multi-control rows preserve a passive swipe area and reflow without tiny targets.
- [ ] Cards have compact padding, clear values/labels and actual portraits where useful.
- [ ] Long labels, selected captions and large values fit without clipping consequences.
- [ ] Tap, swipe, disabled, selected, focus, popup, Back and draft behavior remain usable.
- [ ] Both ends of long lists remain reachable after rebuilding or returning to a page.
- [ ] Visually inspected rendered upright 360×640, 390×844 and 540×960 layouts.
- [ ] Relevant checks pass; report simulated input separately from physical phone testing.

Use `launch.ps1 -TestScript tests/rendered/<runner>.gd` for focused rendering/input
checks. Choose the runners for the changed surface from [tests/README.md](../tests/README.md):
`menu_scroll_audit_runner`, `illustrated_picker_touch_runner`, `stats_editor_runner`,
`rules_navigation_runner`, `rules_back_runner`, `wave_menu_runner`, `wave_editor_runner`,
`save_slot_picker_runner`, `mobile_campaign_controls_runner`, and the relevant map,
tower, currency or parchment runner. `-StyleTests` covers welcome and Campaign
navigation; it is not proof of every editor or physical iOS/Android behavior.

This reference was checked against the current shared components and screen owners.
Rendered captures under ignored `artifacts/` are review evidence, not portable theme
assets; regenerate them for future UI changes. The tracked
[approved Waves reference](references/ui-waves-reference.png) remains the visual
layout reference, with the uniform border rules above overriding its older mixed
border widths.
