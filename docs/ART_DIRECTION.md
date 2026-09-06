# Minimal palette artwork

Current direction: extremely simple flat drawings with solid black outlines. No painted textures, lighting, gradients, noise or decorative particles. Active artwork is native Godot drawing code; no image generation is needed for these elementary shapes.

- Ground: forest #95aa83, forge #bb8c76, crypt #7fa6aa, sanctuary #ae879b.
- Ink: #000000. Paper/socket: #e8ddbd. Road: #dfd0ab.
- Tower accents: ochre #e0b568, coral #db8d73, lavender #b49dcc.
- Portals: mint #93c9bc for the core; lavender for rifts; black centers.
- Terrain: borderless tiles under one shared black world grid. Grid cells match Balance.TILE (300 units); centered lines are 6 world units wide and extend through unowned territory. Draw the grid above all terrain and road crossings, below battlefield objects and controls. Only visible rows and columns are drawn. Roads share their existing route geometry and meet at each edge center.
- Scenery: at most three tiny outlined symbols per tile. Reserve roads, sockets, and full tower silhouettes.
- Towers: pointed tower, flame bowl, obelisk. Enemies: circle, small ghost, block shape; each has two eyes.
- UI: follow [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md). Parchment panels (#e8ddbd), inset surfaces (#dfd0ab), black text, 4-unit structural outlines, 2-unit content outlines, and 0/4-unit corners. Noto Serif semibold titles accompany Noto Sans functional text and bold numbers. Group HUD statistics with whitespace. Ochre marks primary actions and selected tabs; coral marks destructive confirmations. Panels keep close controls and confirmations outside scrolling content. Field-guide and tower-dialog portraits reuse the actual game artwork. Settings offer text enlargement and reduced motion. Tower actions use 48 map units at baseline zoom and scale with their tower, preserving map-space offsets even at screen edges. Desktop layout reflows with window size; mobile applies display-density scaling and safe areas.
- Footer: Unclaimed earnings and Collect all sit above Spendable gold, Gold per second and Lifetime kills. Collection feedback is an ochre outlined badge centered over the visible Unclaimed earnings caption, using its measured text width rather than its container width; it rises 36 pixels over 0.95 seconds and fades after a brief hold.

The artwork implementation lives in scripts/rendering/terrain_art.gd, scripts/rendering/terrain_tile.gd, scripts/rendering/terrain_grid.gd and scripts/rendering/battlefield.gd. The shared UI theme is scripts/ui/interface.gd; bundled fonts and licenses are in assets/fonts. The app icon follows the same palette. Current UI captures are artifacts/style-*.png, regenerated with `./launch.ps1 -StyleTests`.

## Extension contract

Add a biome to `VigilWorld.STYLES` and `VigilWorld.NEW_STYLES`, then give it a ground color and scenery in `scripts/rendering/terrain_art.gd`. New tower/enemy drawings live in the same file. Game statistics stay in `scripts/model/balance.gd`. Preserve road and socket geometry when changing artwork.

Call `refresh_paths()` after changing a region appearance in editor tools or fixtures to invalidate cached terrain. Run `./launch.ps1 -Check` after a renderer change. No image atlases or blend shaders are required.
