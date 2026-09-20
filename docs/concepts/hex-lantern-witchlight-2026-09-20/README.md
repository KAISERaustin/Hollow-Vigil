# Hex Lantern - The Witchlight Shrine

Original five-sprite tower concept family, created September 20, 2026 using the
built-in `image_gen` tool. The user clarified that this commission is for the
**Hex Lantern Tower**. The only subject brief was the user's description:

> A wrought-iron lantern suspended beneath a carved shrine, casting curses upon
> enemies while strengthening the weapons and spells of nearby defenders. Its
> identity is a dangerous protective charm, turning a gathered defense into a
> deadly circle of resistance.

The repository image-generation instructions supplied the production requirements
and general rendering style. No previous tower image, previous tower design,
character artwork, or existing palette was supplied to the generator. Tier one
was generated without an image reference. Later stages use only this new family.
These files are artwork deliverables; this commission does not install them in
the runtime catalog or change gameplay, balance, or branch behavior.

## Finished assets

| File | Cumulative visual addition |
| --- | --- |
| `tier-1.png` | Carved stone shrine framing one suspended wrought-iron violet lantern |
| `tier-2.png` | Paired iron brackets and hanging ward stones |
| `tier-3.png` | Physical forged ritual ring mounted above the shrine |
| `tier-4-curse.png` | Hooked iron arms with mulberry curse lanterns |
| `tier-4-empowerment.png` | Green shield vanes with sword and staff inlays |

Both tier-four specializations start independently from the completed tier-three
image. There is no tier five. The branch labels describe the commissioned art,
not new gameplay definitions.

All five PNGs are transparent RGBA at **1254 x 1254**. The generator returned this
canvas size; the artwork has not been resized or shifted. Core axis: **x = 627**.
Shared ground anchor: **(627, 1156)**. Original roof peak: **(627, 459)**.
The low-opacity antialiased fringe extends to y = 1159; the anchor uses the
visible ground contact, measured at alpha greater than 127.

`family-review.png` shows all five at one fixed scale, with an additional
144-pixel-canvas thumbnail row. `alignment-preview.webp` cycles the same assets
at one placement. These are review artifacts; use the individual PNGs as assets.

## Palette and preservation

`palette.json` records the sixteen colors and intended roles selected before
generation. Tier one uses twelve; the curse branch reserves the mulberry pair,
and the empowerment branch reserves the green pair. Every nontransparent pixel
in every final sprite has been reopened and checked against its permitted RGB
values. RGB and alpha are checked separately.

The original tier-one layer is immutable. Each generated upgrade is masked to
its new feature regions and to pixels where the previous finished image is
transparent, then composited. Every nontransparent RGBA pixel of tier one remains
identical in all four upgrades. Every preceding upgrade layer also remains
identical. This checks material assignments and fixed coordinates, as well as
palette membership.

Before palette conversion, a cutout mask removes isolated nearly invisible
generation residue outside a two-pixel expansion of alpha >= 16 support. Generated
edge alpha inside this support is retained. The subsequent deterministic palette
sweeps preserve all dimensions, geometry, and alpha. There is no dithering.

`sources/` preserves the original generated images. These archival inputs are
not palette-constrained finished assets. `layers/` stores isolated upgrade
additions and selection masks. `validation.json` records saved-file hashes,
palette counts, exact base preservation, and zero offsets across all five.
`prompts.json` contains the full exact prompt set and tool provenance.

## Reproduce the assembly

Run with Python, Pillow, and NumPy from this directory:

```powershell
python build_family.py prepare --source sources/tier-1.png
python build_family.py layer --stage tier-2 --parent tier-1 --source sources/tier-2.png --boxes '[[120,575,442,1030],[812,575,1134,1030]]'
python build_family.py layer --stage tier-3 --parent tier-2 --source sources/tier-3.png --boxes '[[410,35,845,530]]'
python build_family.py layer --stage tier-4-curse --parent tier-3 --source sources/tier-4-curse.png --boxes '[[160,120,440,565],[815,120,1100,565]]'
python build_family.py layer --stage tier-4-empowerment --parent tier-3 --source sources/tier-4-empowerment.png --boxes '[[150,85,440,605],[815,85,1105,605]]'
python build_family.py finish
```

The final command performs the required last color sweep, reopens all five
sprites, checks the sixteen-color family limit and exact prior-layer retention,
verifies common ground placement, and rebuilds the review artifacts. The review
sheet uses the Windows Georgia font. Artwork was visually inspected as a complete
family and at thumbnail scale. Runtime/device rendering is outside this
artwork-only commission.
