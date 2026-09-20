# Stormspire - The Tempest Spire

Original tower artwork created from the user's September 20, 2026 description:

> A stone spire crowned with an enchanted iron staff that calls forked lightning
> down upon several enemies at once. Its identity is a storm mage's ward,
> spreading the fury of the heavens across an advancing warband.

The request used the word "pyre" and then supplied this specific Stormspire
brief; the supplied lightning-spire description governs this artwork. No earlier
tower images or designs were supplied to ImageGen. Written image-generation
instructions govern the style, five-sprite progression, palette and alignment.
This is an artwork package, with no gameplay, balance or runtime catalog changes.

## Finished sprites

| Stage | File | Added structure |
| --- | --- | --- |
| Tier 1 | [tier-1.png](tier-1.png) | Stone spire and enchanted forked iron staff |
| Tier 2 | [tier-2.png](tier-2.png) | Paired iron conductor arms |
| Tier 3 | [tier-3.png](tier-3.png) | Two smaller forks mounted on those arms |
| Tier 4: Skyfork | [tier-4-skyfork.png](tier-4-skyfork.png) | Two supported outer forks; storm-blue accents |
| Tier 4: Thunderward | [tier-4-thunderward.png](tier-4-thunderward.png) | Two enclosing iron ward ribs; violet accents |

The two branch names describe these visual concepts, not new gameplay rules.
Both branches start from the exact same finished tier-three image. Static sprites
contain no airborne lightning or transient attack effects.

- [Complete family review](family-review.png), including small sprite previews.
- [Fixed-position tier-switch preview](alignment-preview.webp).
- Every sprite is **1254 x 1254 RGBA**, with genuine transparency.
- Shared staff/core center: **x = 627**. Ground anchor: **(627, 1164)**.
- Shared placement and measured tier-one bounds: [placement.json](placement.json).
- Exact 16-color family palette and roles: [palette.json](palette.json).
- Final saved-file results and SHA-256 hashes: [validation.json](validation.json).

## Generation and preservation

Generated with the built-in ImageGen tool. Exact prompts for all five calls are
saved in [prompts.json](prompts.json). Raw results are retained in `sources/`.
The approved palette-enforced first tower is retained in
`layers/locked-tier-1.png`. Each subsequent addition has its own PNG, mask and
assembly specification in `layers/`.

Only generated addition pixels inside the specified masks are retained from
upgrade calls. Every already-visible parent pixel, including the base, remains
byte-for-byte unchanged. No sprite is resized or repositioned. Almost invisible
background residue with alpha <= 8 is removed while extracting the initial
silhouette and later addition masks; all remaining alpha values are preserved.
Palette conversion itself changes only RGB values, with no dithering.

The final deterministic color sweep restores the locked first tower's exact
pixels across all five outputs and preserves every previous upgrade. It then
reopens every saved file and checks palette membership, original dimensions,
all base pixels, all parent pixels, the central shaft and ground position, and
unchanged alpha during the final sweep. All five pass with zero off-palette
pixels, zero changed base/parent pixels and zero core displacement.

Run `python build_family.py finish` with Pillow and NumPy to repeat the final
sweep, readback checks and review exports. Review images are resized for display;
the five sprite files and their source layers keep their original dimensions.
Godot is excluded from this concept directory by `.gdignore`.
