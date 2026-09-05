# Minimal palette artwork

Current direction: extremely simple flat drawings with solid black outlines. No painted textures, lighting, gradients, noise or decorative particles. Active artwork is native Godot drawing code; no image generation is needed for these elementary shapes.

- Ground: forest #95aa83, forge #bb8c76, crypt #7fa6aa, sanctuary #ae879b.
- Ink: #000000. Paper/socket: #e8ddbd. Road: #dfd0ab.
- Tower accents: ochre #e0b568, coral #db8d73, lavender #b49dcc.
- Portals: mint #93c9bc for the core; lavender for rifts; black centers.
- Terrain: borderless tiles under one shared black world grid. Grid cells match Balance.TILE (300 units); centered lines are 6 world units wide and extend through unowned territory. Draw the grid above all terrain and road crossings, below battlefield objects and controls. Only visible rows and columns are drawn. Roads share their existing route geometry and meet at each edge center.
- Scenery: at most three tiny outlined symbols per tile. Reserve roads, sockets, and full tower silhouettes.
- Towers: pointed tower, flame bowl, obelisk. Enemies: circle, small ghost, block shape; each has two eyes.
- UI: parchment panels (#e8ddbd), road-colored inset surfaces (#dfd0ab), black text and solid 4-pixel black borders with 4-pixel corners. Ochre marks primary actions and selected controls; coral marks sales and resets. Headings and numbers are bold, icons have 3-pixel strokes, and scrollbars, tooltips, notifications and confirmation dialogs use this same palette. Field-guide portraits reuse the actual tower and enemy drawings.
- Footer: Unclaimed earnings and Collect all sit above Spendable gold, Gold per second and Lifetime kills. Collection feedback is an ochre outlined badge centered over the visible Unclaimed earnings caption, using its measured text width rather than its container width; it rises 36 pixels over 0.95 seconds and fades after a brief hold.

The implementation lives in scripts/rendering/terrain_art.gd, scripts/rendering/terrain_tile.gd, scripts/rendering/terrain_grid.gd and scripts/rendering/battlefield.gd. The app icon follows the same palette. Preview screenshots: artifacts/minimal-tiles-four-biomes.png, minimal-tiles-same-biome.png, minimal-game-540.png and minimal-game-360.png.

## Extension contract

Add a biome to `VigilWorld.STYLES` and `VigilWorld.NEW_STYLES`, then give it a ground color and scenery in `scripts/rendering/terrain_art.gd`. New tower/enemy drawings live in the same file. Game statistics stay in `scripts/model/balance.gd`. Preserve road and socket geometry when changing artwork.

Call `refresh_paths()` after changing a region appearance in editor tools or fixtures to invalidate cached terrain. Run `./launch.ps1 -Check` after a renderer change. No image atlases or blend shaders are required.
