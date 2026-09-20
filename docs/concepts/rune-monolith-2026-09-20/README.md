# Obelisk - The Rune Monolith

Original five-sprite artwork family commissioned September 20, 2026. The request
called for a new Pyre tower and supplied the Obelisk / Rune Monolith description;
that supplied description alone defines this design. No previous tower or other
existing artwork was supplied to ImageGen, opened as a visual reference, or used
as a source layer. The written image-generation and app-style instructions govern
rendering, progression, palette, and alignment.

> An ancient standing stone inscribed with binding runes, gathering dark sorcery
> into slow, devastating strikes against powerful foes. Its identity is an
> enduring magical ward, raised to destroy creatures ordinary arrows struggle to fell.

## Delivered sprites

| File | Stage | Addition |
| --- | --- | --- |
| `tier-1.png` | Tier 1 | Ancient standing stone, three binding sigils, low rubble |
| `tier-2.png` | Tier 2 | Two carved binding buttresses |
| `tier-3.png` | Tier 3 | Supported angular stone binding arch |
| `tier-4-oathbind.png` | Tier 4, branch A | Two mineral-green ward tablets |
| `tier-4-doomseal.png` | Tier 4, branch B | Iron focusing crown and muted garnet shard |

Branch names describe the visual concepts, not implemented gameplay mechanics.
This folder delivers artwork; it does not replace runtime assets, rename content
IDs, introduce abilities, or alter balance.

All five PNGs are **1254 x 1254 RGBA**, front-facing, using the same unscaled core
and camera. Shared placement is **core x = 627, ground anchor = (627, 1156)**,
with visible ground ending at row 1155. The generator returned 1254-pixel sources
instead of the initially requested 1024 pixels. Their native resolution is
preserved. Upgrade silhouettes may grow upward or sideways; do not center each
sprite by its overall bounds or crop it separately.

## Review and verification

- `family-review.png`: all five sprites at one fixed scale, with 128-pixel-canvas
  previews and the selected 16-color palette.
- `alignment-preview.webp`: five stages switched at one fixed placement.
- `palette.json`: all 16 exact RGB colors, material roles, and placement metadata.
- `validation.json`: saved-file color, alpha-border, base-preservation, landmark,
  dimension, ground-coordinate, and SHA-256 checks for every final sprite.

Verified: the complete family uses exactly 16 colors across visible pixels;
individual sprites use 10, 10, 10, 12, and 14. Every nontransparent tier-one pixel
is byte-identical throughout the family. Each inherited stage is also preserved
exactly, including its alpha. Both final branches descend independently from
tier 3. Core and ground landmark offsets are zero; all visible ground anchors
match, and no sprite touches a canvas edge. All five were inspected together
at review scale and at small display size. No gameplay or device tests apply to
this artwork-only delivery.

## Source and layered assembly

Generated with the **built-in imagegen tool**, one base generation followed by
four image edits. The exact final prompt set is in `prompts/`. Each edit used
the actual completed predecessor from this folder; both branch calls used the
same completed `tier-3.png`. `sources/` preserves the untouched generator output.
Those source images are not palette-enforced deliverables.

`layers/locked-tier-1.png` is the immutable palette-enforced base. Separate
addition PNGs, masks, extraction polygons, and per-stage metadata preserve the
construction history. Only the requested additions survive each source edit;
repainted versions of existing components are discarded. Parent pixels take
precedence over additions, including antialiased edges. Source offsets are
integer translations, not resizing or redrawing.

`assemble.py` applies the explicitly authorized deterministic palette correction
and masked layer assembly. Material-aware color mapping keeps neutral stone
from becoming violet and reserves green/garnet for their designated additions.
`finish_family.py` performs the required final color-only sweep, restores the
locked base and inherited colors, saves and reopens every sprite, verifies all
checks, then makes review-only resized derivatives. Final sprite alpha, geometry,
pixel positions, and dimensions are preserved during the sweep.

Run with Python plus Pillow and NumPy from this folder:

```text
python assemble.py tier-1 --dx -7
python assemble.py tier-2 --parent tier-1 --region 210 625 1040 1156
python assemble.py tier-3 --parent tier-2 --dy -12 --region 350 85 905 770
python assemble.py tier-4-oathbind --parent tier-3 --branch ward --dy 35 --mask-polygons layers/oathbind-polygons.json
python assemble.py tier-4-doomseal --parent tier-3 --branch strike --dy -15 --mask-polygons layers/doomseal-polygons.json
python finish_family.py
```

The review generator uses Windows Segoe UI for its labels. Review-sheet and
animation backgrounds, labels, and resampling are not part of the five sprite
assets and are not subject to the sprite palette limit.
