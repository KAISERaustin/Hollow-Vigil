# Hollow Vigil UI theme — Pickard

Version 3 · Moonlit iron · September 16, 2026

## Authority and scope

**The Pickard main-menu image is the primary source of truth for the entire UI.**
Use its darker tone, charcoal-green world, angular armor, muted red cloth,
parchment moon and strong silhouettes as the style for future features.
The Campaign and Settings buttons over that image are not the visual reference.
The opening screen is the foundation of the theme, not an exception to it.

![Primary UI style reference: Pickard main-menu artwork](../assets/ui/pickard-menu-background.png)

Read this file before adding or changing UI. It supersedes the earlier
parchment-first direction in Version 2. The [original Pickard reference](../assets/ui/pickard-reference.jpg)
remains the character reference. The older [Waves screenshot](references/ui-waves-reference.png)
remains useful for card hierarchy and spacing, not for the new color direction.
[UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md) is the companion screen-recipe guide;
[ART_DIRECTION.md](ART_DIRECTION.md) governs artwork and [UI_MENU_TREE.md](UI_MENU_TREE.md)
governs navigation. Keep those documents consistent with this theme.

This document establishes the default for future work. The current runtime still
has many tan parchment surfaces, yellow buttons and older semantic fills; writing
this specification does not mean those screens have already been recolored.
Preserve their established layout and interactions while applying this theme in
future UI implementation. Do not add gameplay or restore retired controls merely
to demonstrate a visual style. Explicit subsequent user instructions take precedence.

## Visual language

- **Dark foundation:** charcoal, deep forest green and quiet near-black scenery.
- **Readable surfaces:** opaque dark iron/green-gray panels above the foundation,
  with warm moon-colored text. Large tan pages are no longer the default.
- **Restrained accents:** aged bone/metal for emphasis, muted cloak red for danger,
  sparse diamond identity marks, and quiet highlights rather than saturated fills.
- **Strong geometry:** compact rectangular cards, angular artwork, solid black
  frames and horizontal row dividers. Keep silhouettes clear at phone size.
- **Material:** subtle grain, worn metal and weathered cloth drawn from the image.
  Decorative texture stays low contrast beneath small text and never becomes noise.
- **Composition:** artwork gets breathing room; dense information gets calm surfaces.
  A settings page can convey the image's tone without putting a knight behind every field.

Use the same language for menus, lists, dialogs, editors, HUD and new features.
Avoid bright yellow slabs, pastel panel stacks, glossy bevels, decorative shadows,
glow, glass blur, neon, capsule controls, modern dashboard gradients and pulsing
chrome. Preserve existing game illustrations until artwork changes are requested;
UI styling must not silently recolor content identities or gameplay cues.

## Palette and color roles

These are **design-role values for implementing the darker theme**, interpreted
from the main image and adjusted for reading contrast. They are not a claim that
these named roles already exist in the runtime. Centralize them through the shared
UI owner when implementing them; never scatter per-screen color overrides.

| Design role | Value | Use |
| --- | --- | --- |
| Foundation | `#141B1A` | Dark page background and quiet space around artwork |
| Deep forest | `#192322` | Illustrated atmosphere; matches the existing forest-tint token |
| Panel | `#2B3533` | Main reading surfaces, cards and dialogs |
| Inset | `#222A29` | Entry fields and recessed information groups |
| Raised control | `#46514D` | Secondary buttons and other interactive surfaces |
| Ink | `#000000` | All enclosure borders and row dividers |
| Moon text | `#E8DDBD` | Primary text and essential icons on dark surfaces |
| Weathered text | `#B8B5A7` | Supporting text on Panel/Inset/Foundation |
| Aged metal | `#B8AA87` | Restrained primary-action fill or selected marker |
| Text on aged metal | `#141B1A` | Labels/icons on the lighter primary-action fill |
| Cloak red | `#623F39` | Destructive-action fill with Moon text and an explicit verb |
| Disabled surface | `#303936` | Inactive controls, with legible Weathered text |
| Scrim | Black at 65% | One overlay behind a blocking modal |

Black remains the fixed outline color, not the text color on a dark panel. Light
icons belong on dark controls; dark icons belong on light controls. Preserve
contrast through surface differences and clear labels without adding a second
border or thickening the black rim. Primary actions should feel like worn metal
or moonlit bone, not the bright gold Campaign/Settings buttons currently shown.

These are semantic roles: muted red in a portrait can identify a cloak, whereas
muted red on Delete communicates danger. Never rely on color alone. Check at
least 4.5:1 for essential text against its actual composited background. Make
interactive boundaries recognizable through fill, shape, label and spacing;
check 3:1 contrast for meaningful graphical indicators. Do not treat the black
rim against near-black scenery as sufficient on its own.

Do not tint a whole control tree: it also muddies text, art and borders. The old
parchment renderer currently applies to selected tan/gold/coral colors; it does
not automatically texture new dark colors. Add any dark material treatment to
the shared surface owner, with quiet texture and a solid readable base. Keep
text, frames and content portraits independently styled.

## Borders, corners and spacing

All visible UI enclosures and row dividers use **3 logical UI units of solid
black**, owned by `VigilInterface.OUTLINE`. Never thicken them for selection,
focus, hover or press. Use 4-unit rectangular corners (`RADIUS`), or 0 for
edge-to-edge chrome. Draw abutting edges once. Layout-only containers stay
transparent and borderless; artwork contours retain their own art rules.

| Shared token or layout | Units |
| --- | --- |
| `OUTLINE` / `RADIUS` | 3 / 4 |
| `SCREEN_PADDING` | 12 inside the safe area in the full-page shell |
| `PADDING` | 16 for ordinary surfaces |
| `CARD_PADDING` | 12 |
| `INSET_PADDING`, `CARD_GAP` | 8 |
| `GAP` | 12 between sections and actions |
| Value-to-label gap | 4 |
| `TARGET` | 48 minimum screen-control height; 48×48 icon targets |
| Page/footer primary action | 52 high |
| Compact identity portrait | Usually 48; preserve aspect ratio |

Use the 4-unit spacing scale: 4, 8, 12, 16, 24, 32, 48. Existing reusable layouts
also contain 14-unit menu/confirmation gaps, 6-unit form-caption gaps and 6-unit
quantity-badge padding. Retain their geometry during a color-only change; use
the shared defaults for new compositions. Apply padding once, avoiding doubled
StyleBox margins and container padding. Cards should fit their content rather
than manufacture empty height; full-page shells still fill their safe viewport.

## Typography and content hierarchy

Use bundled Noto Sans regular, semibold and bold for functional text and numbers;
Noto Serif semibold for major headings. The Pickard image's solemn, angular
character comes through composition and material, not an unreadable novelty font.

| Role | Size and treatment |
| --- | --- |
| Page title | 28 in the current shell; large-title helper defaults to 30, serif semibold |
| Object/dialog title | 24, serif semibold |
| Compact title | 22 or 18, sans bold |
| Section heading / ordinary stat value | 18, sans bold |
| Featured value | 24, sans bold |
| Body / ordinary button | 16, regular / semibold |
| Supporting label / compact action | 14 |
| Metadata | 12 minimum; never for essential action consequences |

Descriptions align left and wrap. Values are bold above clear labels; retain
units and exact transaction prices. Use sentence case for controls. The live
PICKARD wordmark and short subtitle can retain their uppercase, spaced lettering.
Do not copy that treatment into every field or long button label.

`UI.fitted_heading()` handles existing compact single-line titles, fitting from
24 down to 16 and retaining the full accessible name. Ordinary text wraps rather
than shrinking. Shared fonts use tabular figures and the currency glyph; keep
source/accessibility wording meaningful and measure the displayed coin text.

## Page positions and fixed navigation

```text
Safe top + 12
[ Back ]  Screen title                         [ contextual action ]
                 12-unit gap
┌ Scrolling content ──────────────────────────────────────────────┐
│ Cards, option rows, fields, descriptions                         │
│ First and last item remain reachable                            │
└─────────────────────────────────────────────────────────────────┘
                 12-unit gap
[ Primary progression / save action ]
[ Secondary action, when needed ]
Safe bottom + 12
```

The shared full-page shell keeps header and footer fixed; only the middle scrolls.
Back is a square arrow at the top left, with an accessible destination name. The
title expands into the remaining width. A required contextual action or Close
sits at the right; do not add Close to a page that only needs Back. Align content
to the same left/right inset. Keep the existing footer's stacked action order.

Opening another page resets its content scroll. Back, Escape and Android Back
follow the current route and preserve draft/discard behavior. Reuse the protected
Back control so one press cannot navigate twice. Opening navigation during a game
preserves its held session and prior pause state.

## Option rows: left information, right action

This is the default for repeated choices, categories and editable options inside
a scrolling list. **The whole row must not become a button.**

```text
[portrait] Name or setting                         [ Open / Select ]
           Optional explanation or current state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[portrait] Next name or setting                    [ Open / Select ]
           Optional explanation or current state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. Put an optional portrait on the left, a wrapping description in the expanding
   middle, and the explicit action at the far right, centered vertically.
2. Reuse `UI.action_row()`: 12-unit gaps, 64 minimum row height, action at least
   88 wide and 48 high. Illustrated picker/browser rows use 76 minimum. Let
   longer descriptions increase height.
3. Keep **one black 3-unit divider below every option row**, spanning the row
   width. The helper draws it already; do not double it with another separator.
   Selected and disabled rows keep their line. Choice lists use zero extra
   row-container separation, centering contents between the lines.
4. Align the action column across the list. Reserve enough width for both Select
   and Selected, preventing selection from shifting the description and portrait.
5. If one row needs several controls, group them together on the right. Use at
   least 8 units between targets, preferably 12. At narrow widths stack/wrap that
   right-side group or place a right-aligned continuation below the description.
   Keep 48-unit heights, clear labels and the same visual/focus order. Extend the
   shared component for this layout rather than duplicating local variants.
6. Keep the left information area and row gaps passive so a finger can start a
   vertical swipe without choosing an option. A drag across a button must cancel
   the pending tap when the scroll owner takes the gesture.

Existing full-width navigation buttons, fixed footer actions, compact mode tabs
and direct save-slot choices have their own layouts. Preserve those compositions;
the right-side rule applies to descriptive option rows. A framed passive card
already separates its contents; do not underline every description line or stat cell.

### Numeric and form rows

Use `UI.number_row()`: wrapping label left, optional preview before the input,
and a centered numeric field at the right. The input starts at 112×48; the row
starts at 72 high and grows with its caption. Keep its bottom divider and 12-unit
gaps. Retain default-value context supplied by the editor.

Numbers are directly typeable, select all on focus and request a numeric mobile
keyboard. Preserve the helper's hidden increment/decrement arrows, including
empty icon overrides. Do not replace this with tiny plus/minus controls.
Use `UI.style_entry()` for fields and `UI.form_field()` for a caption above an
editor. Toggles visibly say On/Off. Text selection, keyboard entry and sliders
retain their own input behavior.

## Buttons and interaction states

| Purpose/state | Dark-theme presentation |
| --- | --- |
| Primary | Aged-metal fill with dark semibold text; restrained emphasis |
| Secondary | Raised-control fill with Moon text |
| Destructive | Cloak-red fill with Moon text and an explicit verb |
| Default | 3-unit black border, 4-unit corners, at least 48 high |
| Hover | Identical to resting appearance, including icon tint; no tooltip |
| Pressed | Contents move down 1 unit; target and border remain fixed |
| Selected | Explicit state wording plus underline/marker; do not rely on color alone |
| Disabled | Disabled surface and legible supporting text; reason nearby when needed |
| Keyboard focus | Keyboard navigation retained, without an added ring |
| Pending | Stable dimensions, operation-specific status, duplicate activation prevented |

Use one obvious primary action for a task. Preserve explicit Cancel and destructive
consequences. Buttons may wrap and grow; short trailing row actions stay compact.
The existing `UI.gold_button()` and accent helpers are reuse points for future
semantic styling, not instructions to retain saturated yellow/coral fills.
Do not globally change world gold, currency or tower artwork to restyle a UI button.

## Cards and reusable screen patterns

A content card reads in this order: identity/title and optional right-side status;
divider when needed; bold values above labels; native portrait/name/role with
trailing count; actions. Use 12-unit card padding, 8-unit cell gaps and 12-unit
section/action gaps. Dark-theme surfaces and text apply throughout the nesting.

| Surface | Preserve this structure | Shared owner |
| --- | --- | --- |
| Saved games | Separate name/mode cells, wrapping name, compact mode, progress cells and actions | `saved_game_card.gd` |
| Settings, Sound, Account, reports and notes | Fixed header, scrolling forms/notes, inline feedback and reachable actions | `unified_menu.gd`, `save_slots_panel.gd` |
| My builds, Community, Backups | Scrolling entries/details and state/recovery messages; Save privately before Share to Community | `unified_menu.gd`, `contents_checklist.gd` |
| Illustrated picker | Fixed title/Close and divider; scrollable portraits, descriptions and trailing Select | `illustrated_picker.gd` |
| Rules | Categories → item → editor, portraits, trailing Open, fixed draft actions | `rules_browser.gd`, `unified_menu.gd` |
| Stats editor | Distinct labeled Default/Added sections where supported; one headed card per added rule with related fields/disable action together | `stats_editor.gd`, `UI.rule_card()`, `campaign_level_rules.gd` |
| Waves | Title/status, divider, four stat cells, enemy roster, trailing quantities, actions | `wave_summary.gd`, `wave_balance.gd` |
| Confirmation | Centered content-sized panel; consequences above confirm and Cancel; scroll long details | `confirmation_popup.gd` |
| Tower details | Compact identity/portrait, existing management actions, contextual Back/Close, scrolling details and comparisons | `tower_dialog.gd`, `stat_comparison.gd` |

Keep Default/Added and other semantic distinctions through explicit headings and
restrained markers. The current green Added and purple rule fills are legacy
color assignments, not a reason to introduce bright pastel blocks into new dark
screens. Keep their grouping while implementing new shared semantic surface roles.
Do not revive retired Abilities/Attributes tabs or gear editing flows just because
older descriptions or reusable code mention them.

Wave stat grids use four columns at 400 available grid units or more, otherwise
two. Stack further if essential labels require it. Pickers fit the owning safe
viewport with 12-unit clearance, up to 480 wide and 560 high; direct choices size
to content. The current confirmation helper fits its content, normally up to 380
wide with 16-unit padding. Reuse fitting owners rather than hard-coded screen positions.

## Illustrated screens and gameplay positions

**Main menu:** the reference composition. Full-bleed Pickard artwork with live
parchment-colored title/subtitle and sparse diamond ornament in the dark sky.
Keep the knight, helmet, sword, shield and boots clear of controls. Artwork fills
the viewport; controls remain inside safe areas, below the hero, and reachable
through scrolling on short screens. Current buttons are centered, 56 high, up to
320 wide with a 14-unit gap. Retain that geometry when styling; their current gold
fill does not define future UI colors. Reuse `welcome_menu.gd` / `welcome_art.gd`.

**Campaign map:** fixed Back/title above six illustrated biome sections, with one
3-unit black divider between chapters. Preserve edge-to-edge scenery, native
numbered destinations, locked/current/completed meanings and at least 48-unit
level targets. Keep labels clear of scenery and route crossings. Its world art
follows the art guide; its controls use this shared UI theme.

**Battle:** top toolbar with Back, Pause, Speed, Waves and Start wave; terrain
fills the rest. One row below it contains three passive cards for numbered level
identity, currency and wave count. Preserve that arrangement, wrapping text without
shrinking it. `floating_game_hud.gd` owns the cards and lets gestures reach the world.

The build strip remains bottom-aligned, horizontally scrollable, with icon-only
squares at least 48×48, 8-unit gaps and safe-area clearance. Keep the battlefield
visible. Preserve existing tower management, placement and dismissal interactions.
Tower-attached actions/earnings badges retain world anchors; screen HUD text must
not shrink with camera zoom. Applying the theme changes presentation, not camera,
build transactions, save compatibility or level progression.

## Scrolling, focus, feedback and motion

- Use `UI.keyboard_scroll()` / `touch_scroll.gd` for touch, wheel and keyboard
  scrolling. Menu rails remain hidden; vertical pages disable horizontal scrolling.
- Labels, portraits, passive cards, gaps and disabled rows must allow swipes.
  Open controls on a completed tap, not initial touch-down that steals a swipe.
- Rebuilt/dynamically added rows keep the correct scroll owner. Text fields,
  range controls and nested scroll areas retain their own input ownership.
- Fit popups to the safe viewport, reveal the selected/focused item and restore
  focus on dismissal. Only the top active modal receives input; prevent tap-through.
- Keep errors near the task and reveal inline feedback after footer actions.
  Empty, locked and failed states explain the state and available next action.
- Preserve native keyboard overlay behavior and test entry/dismissal separately
  from scrolling. Icon-only controls need explicit accessible names.
- Use restrained motion: existing control feedback around 120 ms and panel
  transitions around 180 ms; no bounce or continuous pulses. Earnings retain
  their existing 36-unit rise over 0.95 seconds. Do not add decorative animation.

## Implementation and review

[`scripts/ui/shared/interface.gd`](../scripts/ui/shared/interface.gd) owns shared
tokens and primitives; `scripts/ui/shared/` owns reusable presentation. Introduce
semantic dark surface/text/action roles there before composing new screens.
Review every affected consumer, including button states, input caret/placeholder,
popup themes, disabled text, icon colors and currency glyph contrast. The current
`UI.TEXT` is black and `UI.PANEL` is light: using those unchanged on a new dark
surface is not sufficient. Keep content art and world colors independent.

For each new or changed screen:

- [ ] The Pickard image's dark mood is the dominant style; legacy parchment pages/yellow buttons are not the palette authority.
- [ ] Text and icons remain readable on their final surfaces, including disabled and selected states.
- [ ] Borders are black and 3 units, corners 4/0, with shared edges drawn once.
- [ ] Page navigation stays fixed; descriptive rows have right-side actions and one divider per row.
- [ ] Multiple controls leave a passive swipe area and reflow without tiny targets.
- [ ] Cards preserve compact padding, value/label hierarchy and meaningful portraits.
- [ ] Long names, large values, selected captions and exact costs fit.
- [ ] Taps, swipes, keyboard focus, popup dismissal, Back and draft behavior work.
- [ ] Both ends of lists remain reachable after page rebuilds and return navigation.
- [ ] Rendered 360×640, 390×844 and 540×960 upright portrait layouts are visually inspected.
- [ ] Relevant checks pass; simulated input is reported separately from physical iOS/Android testing.

Choose focused runners from [tests/README.md](../tests/README.md). Menu/row work
uses `menu_scroll_audit_runner` and `illustrated_picker_touch_runner`; editors use
`stats_editor_runner`, `rules_navigation_runner`, `rules_back_runner` and the wave
runners. Use the relevant saved-slot, map, tower, currency and surface checks when
those owners change. Run via `launch.ps1 -TestScript tests/rendered/<runner>.gd`.
`-StyleTests` covers welcome and Campaign navigation, not every screen or device.

The layout inventory above was reviewed against current source and rendered menu
and picker captures. Those captures establish existing behavior, not completion
of the future dark restyle. Review images under ignored `artifacts/` are regenerated
as needed; the tracked Pickard image at the top is the durable style authority.
