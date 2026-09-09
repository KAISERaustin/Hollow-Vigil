# Minimal palette artwork

Current direction: extremely simple flat drawings with solid black outlines. No painted textures, lighting, gradients, noise or decorative particles. Active artwork is native Godot drawing code; no image generation is needed for these elementary shapes.

Gear direction, revised September 7, 2026: the user requested the greater detail
shown in the upgraded portal references. All eighteen gear objects use layered
silhouettes, thick ink contours, carved wood, parchment/bone, stone, iron,
colored insets and brass fittings. Preserve flat fills and sharp geometry while
adding structural detail. Gear is drawn natively through the reusable families
in `scripts/rendering/actors/gear/`; see [GEAR.md](GEAR.md). Render transparent
exports and the complete board with `tests/rendered/gear_art_runner.gd`.

UI texture direction, extended September 7, 2026: tan UI backgrounds use
`assets/ui/welcome-parchment.png`, generated paper with quiet fibers and mottling.
The shared style applies it to menus, cards, buttons, fields and chrome, with
yellow/red parchment variants for semantic actions; world artwork remains flat.
The asset and generation prompt are documented in `assets/ui/WELCOME_ART.md`.
The main menu is a night-watch cover with deep forest paper (#283b36), a large
stacked parchment wordmark, a mint seal and a moonlit sanctuary landscape.
Its two gold buttons retain their exact existing treatment and dimensions.

Boss direction, revised September 6, 2026: use native flat drawings in
`boss_art.gd`, referenced against the current tiles, core/rift portals and enemy
lineup. Match their solid palette, angular silhouettes, black contours and spare
interior marks; no gradients, texture or sprite matte. Keep the floating antlered
Warden, fire-spirit Cinder Reliquary, spectral Bell and haloed Prior recognizable.
Warden and Reliquary have no arms or legs. Bosses glide without gait animation.
Use 0.51 artwork scale (15% below the former 0.6). Titles use the shared Noto
Serif semibold in parchment nameplates with thin ink borders, with no weakness
subtitle. Health, root shield and ward indicators remain separate. Legacy sprites
in `assets/bosses/` are reference history and are not loaded by the renderer.

- Ground: forest #95aa83, forge #bb8c76, crypt #7fa6aa, sanctuary #ae879b.
- Ink: #000000. Paper/socket: #e8ddbd. Road: #dfd0ab.
- Tower accents: ochre #e0b568, coral #db8d73, lavender #b49dcc.
- Portals: mint #93c9bc for the core; lavender for rifts; black centers.
- Terrain: Campaign landscapes use the authored level geometry and shared biome art. Roads follow the authored paths continuously and remain legible beneath battlefield objects and controls.
- Scenery: at most three tiny outlined symbols per tile. Reserve roads, sockets, and full tower silhouettes.
- Towers: pointed tower, fire-crowned masonry watchtower, obelisk and lightning spire. Pyre uses a tall stone shaft, crenellated parapet, black arched furnace and layered flat flames, borrowing the portals' cut-stone construction. Its tiers and both final branches compose `scripts/rendering/actors/fire_tower_art.gd`; preserve the common socket anchor and attack outlet. Enemies: circle, small ghost, block shape; each has two eyes.
- UI: follow [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md) Version 2, **Parchment cards**, and its saved Waves reference for all future UI. Every UI enclosure and divider uses the same black 3-unit border (`VigilInterface.OUTLINE`), with 0/4-unit corners. Use shared parchment panels (#e8ddbd), inset surfaces (#dfd0ab), muted blue-gray saved-games page backgrounds (#b8c4c6), clean cards with bold values above labels, and native portraits beside identity information when applicable. Use 12-unit card padding, 8-unit inset padding and cell gaps, and 12-unit section/action gaps. Noto Sans carries functional text and compact titles; Noto Serif is reserved for large titles. Ochre marks primary actions and selected tabs; coral marks destructive confirmations. Preserve fixed navigation, scrolling, touch targets, density scaling and safe areas. World artwork outlines retain their established weights.
- Campaign play: one compact parchment control bar above edge-to-edge terrain. Level identity and live values sit in compact floating parchment cards with the shared 3-unit black border and 4-unit corners. Fill one row below the toolbar with three cards: numbered level title (1. Briar Bend), gold and wave count; no shadows, glow, battlefield enclosure or bottom action panel. Reuse the shared toolbar and floating HUD; respect safe areas for text and controls.
Collection feedback is an ochre outlined badge centered over the visible Unclaimed earnings caption, using its measured text width rather than its container width; it rises 36 pixels over 0.95 seconds and fades after a brief hold.

The artwork implementation lives in scripts/rendering/terrain/terrain_art.gd, scripts/rendering/terrain/terrain_tile.gd, scripts/rendering/terrain/terrain_grid.gd and scripts/rendering/battlefield.gd. The shared UI theme is scripts/ui/shared/interface.gd; bundled fonts and licenses are in assets/fonts. The app icon matches the main menu's forest-green moonlit valley, gold watchtower and mint gateway, as documented in docs/APP_ICON.md. Current UI captures are artifacts/style-*.png, regenerated with `./launch.ps1 -StyleTests`.

## Extension contract

Ironspike's mounted bow and loaded bolts rotate around the shared projectile
muzzle to match the fired bolt's direction; its socket and pedestal stay fixed.
The existing per-tower firing angle is supplied through the shared sentinel
renderer, and the line-attack component records the actual muzzle-based bearing.
All tiers and both branches reuse the same rotating bow assembly. Portraits and
build previews retain the upright default.

The opening page composes `scripts/ui/shared/welcome_art.gd` illustrations in
`scripts/ui/welcome_menu.gd`: a mint seal, a moonlit valley with a solitary
watchtower, winding road and core sanctuary, and a compact footer rule.
These reusable, stateless Controls call the existing terrain,
tower, enemy and portal drawing library without starting a simulation. Keep the
mode actions centered, the title readable and the art non-interactive. The
welcome-menu rendered checks cover phone layouts and both navigation paths.

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

The campaign world map uses six edge-to-edge biome sections with native scenery, winding ink-bordered trails and one shared 3-unit divider between sections. This user-requested map exception removes the parchment page background and chapter cards. Keep title/Back navigation fixed above the scroll viewport. See the Campaign world map recipe in `UI_STYLE_GUIDE.md`; ordinary dialogs still use the shared parchment system.

Completed levels use `scripts/campaign/cleared_level_art.gd`, a stateless shared drawing component composed by `level_marker.gd`. Broken parchment stone, scattered masonry and an ochre beacon replace the intact marker; chapter bosses use collapsed gate jambs with the same beacon. Numbers remain readable and completion comes only from campaign progress. Flames are flat and static, with no glow or particles. Unfinished destinations retain their existing artwork. Regenerate mobile reference captures with `--script res://tests/previews/cleared_map_preview.gd`.

Currency text uses a centered ochre coin with black rim, inset ring and diamond, matching the existing coin portrait. The reusable color glyph scales with surrounding text; see UI_STYLE_GUIDE.md.

## Hex recipient effects

`rendering/effects/hex_art.gd` shares a violet inked rune vocabulary between enemy vulnerability and allied tower empowerment. Enemy hexes use a hovering eye, three rising side runes and a low seal, following the existing poison bubbles and ice crystals. Poison and ice remain visible when combined with hex; bosses receive a larger hex cue to match their silhouettes. Boosted towers use a quiet flattened broken ring and two small runes at their foundations, drawn with each tower so depth ordering remains intact.

Effects read live status/strength and the shared combat aura query, without visual timers or persistent state. Expired, removed and zero-strength effects disappear; rebuilding towers do not display the boost. `tests/rendered/hex_effect_runner.gd` exports all eight boosted tower families, poison/ice/hex comparisons and combined effects at two animation phases in 360x640, 390x844 and 540x960 portrait views. Run it through `launch.ps1 -ArtSmoke` or `-Check`.
