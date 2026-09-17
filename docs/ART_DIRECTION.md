# Pickard art direction

## Image-asset style authority

Read [APP_STYLE_THEME.md](APP_STYLE_THEME.md) before generating or revising image
assets. It describes both the supplied tier-one tower sheet and Pickard main-menu
image in detail, including palette, shape language, materials, lighting, texture,
atmosphere, asset-specific guidance, and reusable prompts. Those two references
jointly define the style for future images. It is an artwork specification,
separate from the UI theme. Where older notes below describe pastel palettes or
textureless primitives, the new image-asset reference takes precedence for future
art; existing implementation and gameplay contracts remain intact.

Future tower foundations follow the compact crumbly-stone buildup and reusable
prompt in [APP_STYLE_THEME.md](APP_STYLE_THEME.md#tower-foundations-reusable-prompt):
low rubble builds into the lower walls and tapers into the ground, without a
large mound, terrain tile, or change to gameplay placement footprints.

## Character identity and implementation context

Current direction, revised September 16, 2026: the game centers on **Pickard the
knight**. The user-supplied [canonical reference](../assets/ui/pickard-reference.jpg)
preserves his character identity. Preserve the closed angular iron
helmet and dark visor, broad faceted armor, weathered muted red cloak, upright
sword, dark shield with pale diamond, heavy near-black silhouette contours,
parchment moon and layered charcoal-green ruins. Use restrained material facets
and quiet weathering, with strong silhouettes readable at phone size. This
supersedes the earlier extremely-simple-flat-shapes-only direction for new art.
Do not add glow, glossy bevels, bright saturation or decorative particles.

The main menu uses a newly generated full-screen composition based on the
supplied knight, with live accessible title text in the sky and actions over
the dark foreground. `assets/ui/pickard-menu-background.png` fills the viewport;
`assets/ui/PICKARD_ART.md` records the generation prompt. The original reference
JPEG stays unchanged. The standing knight remains the central focus, with
sword, shield and boots visible above the buttons. Existing gameplay art remains
in place until requested revisions apply the reference to its reusable families.
For all future UI, the **main-menu image itself** is the primary style authority:
dark charcoal-green foundations, iron surfaces, parchment-colored text, muted
cloak red and restrained aged-metal accents. The current Campaign/Settings button
colors do not define that style. Read [UI_THEME.md](UI_THEME.md) and Version 3 of
[UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md) for layout and interaction rules. The opening
screen establishes the common theme, not an exception. Preserve black 1-unit
button borders, 1-unit other UI borders and portrait layouts. Historical notes below describe existing assets;
their tan/yellow/pastel UI fills do not override the new dark theme. Shared runtime
UI now uses this palette; fixed iron, steel, violet and bronze action roles coexist in menus without recoloring world artwork.

Gear direction, revised September 7, 2026: the user requested the greater detail
shown in the upgraded portal references. All eighteen gear objects use layered
silhouettes, thick ink contours, carved wood, parchment/bone, stone, iron,
colored insets and brass fittings. Preserve flat fills and sharp geometry while
adding structural detail. Gear is drawn natively through the reusable families
in `scripts/rendering/actors/gear/`; see [GEAR.md](GEAR.md). Render transparent
exports and the complete board with `tools/previews/gear_art_preview.gd`.

Historical UI texture implementation, September 7, 2026: tan UI backgrounds use
`assets/ui/welcome-parchment.png`, generated paper with quiet fibers and mottling.
The shared style applies it to menus, cards, buttons, fields and chrome, with
yellow/red parchment variants for semantic actions; world artwork remains flat.
The asset and generation prompt are documented in `assets/ui/WELCOME_ART.md`.
The main menu uses generated edge-to-edge moonlit Pickard artwork with a live
parchment serif wordmark in the sky and actions over the dark foreground.
Campaign uses the fixed aged-metal primary; Settings uses steel. Their geometry remains shared.

Boss direction, revised September 6, 2026: use native flat drawings in
`boss_art.gd`, referenced against the current tiles, core/rift portals and enemy
lineup. Match their solid palette, angular silhouettes, black contours and spare
interior marks; no gradients, texture or sprite matte. Keep the floating antlered
Warden, fire-spirit Cinder Reliquary, spectral Bell and haloed Prior recognizable.
Warden and Reliquary have no arms or legs. Bosses glide without gait animation.
Use 0.51 artwork scale (15% below the former 0.6). Titles use the shared Cinzel semibold in parchment nameplates with thin ink borders, with no weakness
subtitle. Health, root shield and ward indicators remain separate.

- Ground: forest #95aa83, forge #bb8c76, crypt #7fa6aa, sanctuary #ae879b.
- Ink: #000000. Paper/socket: #e8ddbd. Road: #dfd0ab.
- Tower accents: ochre #e0b568, coral #db8d73, lavender #b49dcc.
- Portals: mint #93c9bc for the core; lavender for rifts; black centers.
- Terrain: Campaign landscapes use the authored level geometry and shared biome art. Roads follow the authored paths continuously and remain legible beneath battlefield objects and controls.
- Scenery: at most three tiny outlined symbols per tile. Reserve roads, sockets, and full tower silhouettes.
- Towers: pointed tower, fire-crowned masonry watchtower, obelisk and lightning spire. Pyre uses a tall stone shaft, crenellated parapet, black arched furnace and layered flat flames, borrowing the portals' cut-stone construction. Its tiers and both final branches compose `scripts/rendering/actors/fire_tower_art.gd`; preserve the common socket anchor and attack outlet. Enemies: circle, small ghost, block shape; each has two eyes.
- UI: follow [UI_THEME.md](UI_THEME.md) and [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md) Version 3. The Pickard main image defines the dark color/material direction. Keep 1-unit black button borders and 1-unit other enclosures/dividers, 0/4-unit corners, 11-unit card padding, 8-unit inset padding/cell gaps and 11-unit section/action gaps. Preserve bold values above labels, native portraits, right-side row actions, fixed navigation and scrolling. Grenze carries controls and body text; Cinzel carries large titles. Use light text on dark surfaces and explicit state/consequence wording. World artwork retains its own palette and outlines.
- Campaign play: one compact control bar above edge-to-edge terrain. Level identity and live values sit in compact floating cards with the shared 1-unit black border and 4-unit corners. Fill one row below the toolbar with three cards: numbered level title (1. Briar Bend), gold and wave count; no shadows, glow, battlefield enclosure or bottom action panel. Reuse the shared toolbar and floating HUD; respect safe areas for text and controls. Their existing parchment fills are legacy presentation; future UI styling follows the dark theme.
Collection feedback is an ochre outlined badge centered over the visible Unclaimed earnings caption, using its measured text width rather than its container width; it rises 36 pixels over 0.95 seconds and fades after a brief hold.

The artwork implementation lives in scripts/rendering/terrain/terrain_art.gd, scripts/rendering/terrain/terrain_tile.gd, scripts/rendering/terrain/terrain_grid.gd and scripts/rendering/battlefield.gd. The shared UI theme is scripts/ui/shared/interface.gd; bundled fonts and licenses are in assets/fonts. The app icon uses a close-up of Pickard's angular iron helmet and muted red cloak against a parchment moon and charcoal-green ruins, as documented in docs/APP_ICON.md. Current UI captures are artifacts/style-*.png, regenerated with `./launch.ps1 -StyleTests`.

## Extension contract

Ironspike's mounted bow and loaded bolts rotate around the shared projectile
muzzle to match the fired bolt's direction; its socket and pedestal stay fixed.
The existing per-tower firing angle is supplied through the shared sentinel
renderer, and the line-attack component records the actual muzzle-based bearing.
All tiers and both branches reuse the same rotating bow assembly. Portraits and
build previews retain the upright default.

The opening page composes the reusable stateless `scripts/ui/shared/welcome_art.gd`
background and diamond ornament. `scripts/ui/unified_menu.gd` owns the viewport
background; `scripts/ui/welcome_menu.gd` owns the safe-area title and actions. Artwork scales
proportionally and never receives input or starts gameplay. Keep the title live,
actions centered and safe-area scrolling available. The welcome layout runner
checks upright phone sizes, artwork clearance, touch targets and navigation.

Add a biome to `VigilWorld.STYLES` and `VigilWorld.NEW_STYLES`, then give it a ground color and scenery in `scripts/rendering/terrain/terrain_art.gd`. New tower/enemy drawings live in the same file. Game statistics stay in `scripts/gameplay/balance.gd`. Preserve road and socket geometry when changing artwork.

Call `refresh_paths()` after changing a region appearance in editor tools or fixtures to invalidate cached terrain. Run `./launch.ps1 -Check` after a renderer change. No image atlases or blend shaders are required.

## Cleared campaign landmarks

The September 7 landscape upgrade applies the portals, Moonwheel and Caltrop
Keep's structural detail throughout all six campaign chapters. The map is an
illustrated landscape with cut-stone watchposts, timber mills, foundries, bell
towers, lunar observatories, ruined keeps and orchard shrines. Use layered flat
materials, masonry courses, roof seams, iron brackets and carved crests. This
campaign scenery exception supersedes the three-tiny-symbol terrain limit above;
chapter terrain density remains unchanged. Biome contours, groves, crags, graves,
streams, moats and lava channels establish places around the winding trail.
Bridges follow actual route intersections. Numbered illustrated destinations
remain the level controls; passive scenery never receives input.

`content/catalogs/chapter_maps.gd` assigns reusable landscape recipes to the
Chapter Level nodes through the removable `map_landscape` presentation component.
`rendering/terrain/map_landmark_art.gd` and `map_nature_art.gd` own drawing parts;
`ui/shared/biome_map_art.gd` owns deterministic placement and crossing geometry.
Reserve full artwork bounds, label text and controls when reflowing. Cache layout
per map instance, with no random redraw changes or state on shared definitions.
All thirty level IDs, unlocks, saves, waves and rewards remain unchanged.
`tests/rendered/campaign_landscape_runner.gd` verifies component isolation and
artwork bounds, and exports every full chapter at 360, 390 and 540 units plus
`artifacts/campaign-landscape-gallery.png`. The map runner also checks landscape
clearance, portrait-phone navigation and both ends of every chapter.

The campaign world map uses six edge-to-edge biome sections with native scenery, winding ink-bordered trails and one shared 1-unit divider between sections. This is the shared theme's illustrated map composition, with scenery as its foundation and no parchment page background or chapter cards. Keep title/Back navigation fixed above the scroll viewport. See the Campaign world map recipe in `UI_STYLE_GUIDE.md`; dialog styling follows the same theme's dark reading surfaces.

Completed levels use `scripts/campaign/cleared_level_art.gd`, a stateless shared drawing component composed by `level_marker.gd`. Broken parchment stone, scattered masonry and an ochre beacon replace the intact marker; chapter bosses use collapsed gate jambs with the same beacon. Numbers remain readable and completion comes only from campaign progress. Flames are flat and static, with no glow or particles. Unfinished destinations retain their existing artwork. Regenerate mobile reference captures with `--script res://tools/previews/cleared_map_preview.gd`.

Currency text uses a centered ochre coin with black rim, inset ring and diamond, matching the existing coin portrait. The reusable color glyph scales with surrounding text; see UI_STYLE_GUIDE.md.

## Hex recipient effects

`rendering/effects/hex_art.gd` shares a violet inked rune vocabulary between enemy vulnerability and allied tower empowerment. Enemy hexes use a hovering eye, three rising side runes and a low seal, following the existing poison bubbles and ice crystals. Poison and ice remain visible when combined with hex; bosses receive a larger hex cue to match their silhouettes. Boosted towers use a quiet flattened broken ring and two small runes at their foundations, drawn with each tower so depth ordering remains intact.

Effects read live status/strength and the shared combat aura query, without visual timers or persistent state. Expired, removed and zero-strength effects disappear; rebuilding towers do not display the boost. `tests/rendered/hex_effect_runner.gd` exports all eight boosted tower families, poison/ice/hex comparisons and combined effects at two animation phases in 360x640, 390x844 and 540x960 portrait views. Run it through `launch.ps1 -ArtSmoke` or `-Check`.

Rule presentation uses dark cards inside a recessed Added section. Preserve one headed card per related rule and keep its fields/disable action together. Retain the labeled Default/Added hierarchy through restrained semantic markers. Use the shared rule-card owner, 1-unit black borders, 4-unit corners and 11-unit padding. Do not restore retired editable capabilities to demonstrate the theme.
