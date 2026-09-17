# Gloamwatch — The Arrow Watchtower

Approved Gloamwatch family, September 17, 2026. The five aligned images now ship
as the rapid tower family through the shared runtime artwork catalog. Saved
content IDs and combat balance remain unchanged.

## Current design

Build the progression cumulatively from the same tier-one image. Preserve the
canvas, ground anchor, door and stair positions, shaft width, roof position,
window positions and camera. Tier 2 adds supports to that base; tier 3 adds
fortification to tier 2. Both tier-four branches independently add their
specialization to the same tier-three image. Added supports may extend outward,
but the underlying tower must not resize or shift between images.

Flag progression: tier 1 has no flags, pole or hanging banner. Tier 2 adds one
oxblood top flag. Tier 3 retains it and adds the front diamond banner. Both
tier-four branches keep those two items; frost adds a pale blue ice flag and
poison adds the established olive poison flag. The fifth illustration is the
poison tier-four branch, not a new gameplay tier five.

All five use the same straight-on front elevation. Center the front door,
central window, and roof apex on one vertical axis. Keep left and right supports
balanced and stair/sill edges horizontal; do not rotate individual tiers into
different three-quarter views.

Match Pickard's simplicity as well as his colors: large uninterrupted masses,
two or three tones per material, heavy silhouettes, and very few broad facets.
Omit individual roof tiles, brick grids, rivet rows, plank grain, fine cracks,
small leaves and scattered gravel. Use a handful of chunky foundation stones.
Communicate upgrades through larger structural shapes, not more surface detail.
Frost and poison remain distinct through a few bold elemental shapes.

Progress from basic to supported to fortified. Every window is an opaque
pitch-black recess with no visible archer, face, eyes, hands, bow or interior
objects. **No arrows or projectiles are baked into any image.**

| Stage | Illustration | Construction |
| --- | --- | --- |
| Tier 1 | [Basic Gloamwatch](level-1.png) | Plain base; no flags or banners |
| Tier 2 | [Supported Gloamwatch](level-2.png) | Added timber supports and top oxblood flag |
| Tier 3 | [Fortified Gloamwatch](level-3.png) | Added corbels, buttresses, iron collar and front banner |
| Tier 4: Frostneedle | [Frost branch](tier-4-frost.png) | Tier-three base plus ice accents and ice flag |
| Tier 4: Poison Arrow | [Poison branch](tier-4-poison.png) | Tier-three base plus poison accents and olive flag |

Poison is deliberately stronger than the first proposal while remaining a
stone watchtower with black windows and a clear doorway.

## Pickard style authority

The [16-color master palette](PALETTE.md) fixes material colors across all five
stages. Eleven shared colors cover structure, wood, cloth and insignia; two
frost and three poison accents complete the family. Upgrades must not brighten
the stone. Pale bone is reserved for small insignia rather than roof, door or
window framing. The palette specification supersedes color drift in earlier
generated concepts and prompts.

The final pass uses [Pickard's main-menu artwork](../../../assets/ui/pickard-menu-background.png)
directly as an image reference. Match its dark foreground rocks, iron and ruins:
charcoal-green and soot foundations, broad angular matte planes, heavy black
contours, quiet print grain, dark oxblood cloth and small aged-bone accents.
Stone is predominantly dark green-gray rather than pale beige masonry. Reduce
fine brick detailing before compromising silhouette and window clarity.

The art authorities are `docs/APP_STYLE_THEME.md` and `docs/ART_DIRECTION.md`.
The matching app palette and UI integration belong to `docs/UI_THEME.md` and
`docs/UI_STYLE_GUIDE.md`; artwork does not inherit fixed UI border widths.

Retain the [shared crumbly-foundation prompt](../../APP_STYLE_THEME.md#tower-foundations-reusable-prompt):
small stones build into lower walls and taper into scattered fragments, without
a large terrain mound or altered gameplay placement footprint.

## Runtime integration

The `rapid`, `frostneedle`, and `thorn_volley` identities and combat rules remain.
The displayed base name is Gloamwatch. A tireless watchman holds the road from
blackened windows, cutting down lesser foes and finishing the wounded with
disciplined bowfire. Frostneedle and Poison Arrow retain their branch names.
Runtime copies in `assets/artwork/tower/rapid/` are byte-identical to these PNGs.
All five catalog bounds are (-25.6, -72.85, 51.2, 76.8), mapping the shared pixel
anchor (512, 1457) to the ground origin at 20 pixels per world unit. Authored
entries never fall back to the old vector drawings at high zoom and are protected
from native rebaking. The shared projectile outlet is at (0, -40), inside the
black front gallery; live wooden arrows remain separate from the images.
An optional catalog alpha cutoff removes faint background residue from cached
runtime textures only; the five approved PNGs remain byte-identical. The prepared
textures are shared across canvases and retain their original colors and anchor.
Use a shared stateless art family for battlefield, previews and portraits.
During attacks, the first visible arrow should appear just outside the active
black window, above its sill and clear of masonry. Projectiles remain separate
from static tower artwork; the shooter stays hidden. Validate target bearings,
occlusion and portrait layouts at 360x640, 390x844 and 540x960 when integrating.

## Provenance

The final placement pass translates the existing fixed-palette images only:
tier 1/2/3 by (+57, 0), frost by (+57, -1), and poison by (+54, +28) pixels.
All five remain 1024 by 1536 with the shared placement anchor **(512, 1457)**,
measured at the center of the lowest front step where its bottom ink stroke begins.
The poison step has an odd pixel width, so its geometric center is 511.5;
the integer anchor rounds to 512 (half-pixel tolerance, no interpolation).
No artwork was regenerated, resized, warped or recolored. Retained RGBA pixels
are byte-identical after translation. No pixels with alpha 128 or higher were
clipped; only faint background residue at canvas edges moved out of bounds.
See [alignment-verification.json](alignment-verification.json).

Use the entire canvas and the same anchor/scale for all upgrades. For a centered
Godot Sprite2D, offset (0, -689) places this anchor at the node origin.
Do not auto-crop and independently center each image by its flag or buttress bounds.
Reproduce with `python tools/gloamwatch_alignment.py SOURCE --output DESTINATION`,
using the unaligned PNGs from commit `c530677` as SOURCE.

The cumulative images were visually compared for shared shaft, door, window,
roof and ground placement, along with the flag sequence. They remain generated
concepts: small internal shape differences remain, especially in the
poison branch, even though the placement anchors now match. This integration
preserves the approved images rather than reshaping their internal architecture.

The final color-only revision uses the user-approved deterministic conversion in
`tools/gloamwatch_palette.py`, applied to the cumulative PNGs from commit
`956745537dda81dd1e0cfbfc21aecec3c40817c5`. It preserves each original alpha channel,
canvas and pixel position without resampling. All nontransparent pixels use a
subset of the fixed palette; the family uses exactly 16 RGB colors in total.
See [palette-verification.json](palette-verification.json) for per-image results.
Alpha blending against a background can produce intermediate displayed colors.
The exploratory AI color edits were not selected because they shifted geometry.

Built-in image generation revised each prior tower's architecture, then used
that revision plus the Pickard image for the final dark, projectile-free pass.
The latest straight-on simplification uses the same Pickard reference directly.
Current cumulative-edit prompts are in [aligned-progression-prompts.md](aligned-progression-prompts.md).
[front-simplified-prompts.md](front-simplified-prompts.md) records the preceding simplification;
[revision-prompts.md](revision-prompts.md) records the preceding dark-palette pass.

The [original concept](gloamwatch-concept.png), [original prompt](prompt.txt) and
[first progression prompts](progression-prompts.md) are historical references.
Their visible archers, brighter masonry and subtle poison directions are
superseded. The current family has rendered checks at 360x640, 390x844 and
540x960; physical iOS/Android device acceptance remains separate.
