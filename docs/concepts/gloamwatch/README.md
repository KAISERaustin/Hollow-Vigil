# Gloamwatch — The Arrow Watchtower

Revised concept family, September 17, 2026. Concept artwork only; runtime art,
content IDs, names, and combat balance remain unchanged.

## Current design

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
| Tier 1 | [Basic Gloamwatch](level-1.png) | Plain shaft and simple roof, no external supports or armor |
| Tier 2 | [Supported Gloamwatch](level-2.png) | Timber gallery braces and slim lower supports |
| Tier 3 | [Fortified Gloamwatch](level-3.png) | Heavy corbels, buttresses, iron collar and protected gallery |
| Tier 4: Frostneedle | [Frost branch](tier-4-frost.png) | Fortified structure with cold fittings and compact frost |
| Tier 4: Poison Arrow | [Poison branch](tier-4-poison.png) | Exterior venom reservoirs, thorn growth, poison drips and fungi |

Poison is deliberately stronger than the first proposal while remaining a
stone watchtower with black windows and a clear doorway.

## Pickard style authority

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

## Future runtime integration

Keep the `rapid`, `frostneedle`, and `thorn_volley` identities and combat rules.
Use a shared stateless art family for battlefield, previews and portraits.
During attacks, the first visible arrow should appear just outside the active
black window, above its sill and clear of masonry. Projectiles remain separate
from static tower artwork; the shooter stays hidden. Validate target bearings,
occlusion and portrait layouts at 360x640, 390x844 and 540x960 when integrating.

## Provenance

Built-in image generation revised each prior tower's architecture, then used
that revision plus the Pickard image for the final dark, projectile-free pass.
The latest straight-on simplification uses the same Pickard reference directly.
Current prompts are in [front-simplified-prompts.md](front-simplified-prompts.md);
[revision-prompts.md](revision-prompts.md) records the preceding dark-palette pass.

The [original concept](gloamwatch-concept.png), [original prompt](prompt.txt) and
[first progression prompts](progression-prompts.md) are historical references.
Their visible archers, brighter masonry and subtle poison directions are
superseded. These illustrations are not runtime- or device-tested sprites.
