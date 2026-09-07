# Minimal palette artwork

Current direction: extremely simple flat drawings with solid black outlines. No painted textures, lighting, gradients, noise or decorative particles. Active artwork is native Godot drawing code; no image generation is needed for these elementary shapes.

Opening-page exception requested September 6, 2026: the tan background uses
`assets/ui/welcome-parchment.png`, generated paper with quiet fibers and mottling.
It is composed beneath the opening card only; game artwork remains flat and
the other menus retain their solid parchment surfaces. Title lettering uses
warm ink and a small ochre offset; motto and footer use the bundled serif.
The asset and generation prompt are documented in `assets/ui/WELCOME_ART.md`.

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
- Terrain: borderless tiles under one shared black world grid. Grid cells match Balance.TILE (300 units); centered lines are 6 world units wide and extend through unowned territory. Draw the grid above all terrain and road crossings, below battlefield objects and controls. Only visible rows and columns are drawn. Roads share their existing route geometry and meet at each edge center.
- Scenery: at most three tiny outlined symbols per tile. Reserve roads, sockets, and full tower silhouettes.
- Towers: pointed tower, flame bowl, obelisk. Enemies: circle, small ghost, block shape; each has two eyes.
- UI: follow [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md). Parchment panels (#e8ddbd), inset surfaces (#dfd0ab), black text, 4-unit structural outlines, 2-unit content outlines, and 0/4-unit corners. Noto Serif semibold titles accompany Noto Sans functional text and bold numbers. Group HUD statistics with whitespace. Ochre marks primary actions and selected tabs; coral marks destructive confirmations. Panels keep close controls and confirmations outside scrolling content. Tower-dialog portraits reuse the actual game artwork. Settings offer text enlargement and reduced motion. Tower actions use 48 map units at baseline zoom and scale with their tower, preserving map-space offsets even at screen edges. Desktop layout reflows with window size; mobile applies display-density scaling and safe areas.
- Footer: Unclaimed earnings and Collect all sit above Spendable gold, Gold per second and Lifetime kills. Collection feedback is an ochre outlined badge centered over the visible Unclaimed earnings caption, using its measured text width rather than its container width; it rises 36 pixels over 0.95 seconds and fades after a brief hold.

The artwork implementation lives in scripts/rendering/terrain/terrain_art.gd, scripts/rendering/terrain/terrain_tile.gd, scripts/rendering/terrain/terrain_grid.gd and scripts/rendering/battlefield.gd. The shared UI theme is scripts/ui/shared/interface.gd; bundled fonts and licenses are in assets/fonts. The app icon uses the separately approved purple woodland and mint gateway illustration documented in docs/APP_ICON.md. Current UI captures are artifacts/style-*.png, regenerated with `./launch.ps1 -StyleTests`.

## Extension contract

The opening page composes `scripts/ui/shared/welcome_art.gd` illustrations in
`scripts/ui/welcome_menu.gd`: a portal-and-sentinel title crest and a miniature
battlefield. These reusable, stateless Controls call the existing terrain,
tower, enemy and portal drawing library without starting a simulation. Keep the
mode actions centered, the title readable and the art non-interactive. The
welcome-menu rendered checks cover phone layouts and both navigation paths.

Add a biome to `VigilWorld.STYLES` and `VigilWorld.NEW_STYLES`, then give it a ground color and scenery in `scripts/rendering/terrain/terrain_art.gd`. New tower/enemy drawings live in the same file. Game statistics stay in `scripts/gameplay/balance.gd`. Preserve road and socket geometry when changing artwork.

Call `refresh_paths()` after changing a region appearance in editor tools or fixtures to invalidate cached terrain. Run `./launch.ps1 -Check` after a renderer change. No image atlases or blend shaders are required.

## Cleared campaign landmarks

Completed levels use `scripts/campaign/cleared_level_art.gd`, a stateless shared drawing component composed by `level_marker.gd`. Broken parchment stone, scattered masonry and an ochre beacon replace the intact marker; chapter bosses use collapsed gate jambs with the same beacon. Numbers remain readable and completion comes only from campaign progress. Flames are flat and static, with no glow or particles. Unfinished destinations retain their existing artwork. Regenerate mobile reference captures with `--script res://tests/previews/cleared_map_preview.gd`.
