# Terrain artwork

The game has four terrain styles, defined by `VigilWorld.STYLES`. They use
native Godot drawing, matching the towers and enemies: muted flat colors,
black silhouettes, angular facets, and small material details.

| Terrain | Scenery | Ground texture |
| --- | --- | --- |
| Forest | Layered pine branches and visible trunks | Sparse grass and leaves |
| Ashen Forge | Faceted rocks with gold fissures | Cracks and stone chips |
| Drowned Crypt | Cracked grave markers in shallow pools | Ripples and reeds |
| Bloodmoon Sanctuary | Violet crystal clusters | Crystal fragments and thorn marks |
| Castle Ruin | Broken ashlar piers and fallen masonry | Sparse cracked flagstones, chips and fissures |

Paths have broken inset wear marks, with their center lane and joining mouths
kept clear. Tower pads have a shallow stone rim and a few joints around the
open center. Ground decoration is capped at 32 small motifs per tile and
reserves room around towers, portals, roads, and the three larger props.
Decoration stays inside each tile and is cached from a separate seeded random
stream; it does not change road geometry, combat randomness, or saved state.

`scripts/rendering/terrain/terrain_art.gd` owns the drawing and
`scripts/rendering/terrain/terrain_tile.gd` owns decoration placement. No external
textures or generated raster assets are needed for gameplay.

Use `./launch.ps1 -TerrainPreview` to render the four-biome comparison, a
16-tile mixed map, matching biomes, and a starter view under `artifacts/`.
`-TerrainTests` checks palette continuity at road mouths, seams, clipping,
and the grid across biome combinations, fractional camera positions, and zooms.
`-ArtSmoke` checks build controls and actor artwork at phone-sized viewports.
