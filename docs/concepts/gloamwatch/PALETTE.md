# Gloamwatch master palette

One 16-color design palette for all five towers. Eleven common material colors,
two frost accents, and three poison accents. Not every tower uses every color.
Transparency is not a seventeenth material color.

| Role | Hex |
| --- | --- |
| Ink, contours and black windows | `#000000` |
| Deep stone shadow | `#151E1D` |
| Roof | `#222A29` |
| Stone base | `#293633` |
| Stone light and dull iron | `#41423C` |
| Small worn stone edges | `#56564E` |
| Timber shadow | `#3D3025` |
| Timber light | `#624B35` |
| Cloth shadow | `#392724` |
| Oxblood cloth | `#613B34` |
| Small diamond insignia | `#BFB295` |
| Frost shadow | `#435862` |
| Frost light | `#758F9E` |
| Poison shadow | `#39442B` |
| Poison base | `#566333` |
| Poison light | `#788346` |

## Fixed material assignments

Use identical stone colors at every tier. Most masonry is Stone base with Deep
stone shadow and Stone light planes. Small worn edges may use `#56564E`; broad
walls, roofs, window frames, door surrounds, stairs and rocks must never become
pale beige. Bone belongs only on small insignia, not architectural highlights.

Roof uses Roof, Deep stone shadow and Stone base. Wood uses the two timber
colors. Every oxblood top flag and hanging banner uses the same two cloth colors.
Frost and poison use their respective accent colors without illuminating or
recoloring adjacent masonry. Upgrades add structure, never brighter stone.

Keep black windows, no visible occupants or projectiles, the simple front view,
compact crumbly foundations, cumulative construction and established flag
sequence. This palette applies to the Gloamwatch concept family and does not
recolor unrelated game assets or change the app's shared UI tokens.

## Reproduction and verification

Run `python tools/gloamwatch_palette.py SOURCE_DIRECTORY OUTPUT_DIRECTORY` with
Pillow and NumPy. Source files must be the pre-palette cumulative PNGs from commit
`956745537dda81dd1e0cfbfc21aecec3c40817c5`, not the already converted outputs.
The converter checks every visible RGB value against this palette and compares
the entire alpha channel byte for byte. It performs no resizing or resampling.
The verification JSON records the subset used by each tower and the family union.
