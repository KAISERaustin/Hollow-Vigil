# Moonwheel - The Crescent Reliquary

Original Moon Wheel Tower artwork, created September 20, 2026 with the built-in
ImageGen tool from the user's brief: a weathered stone pedestal bearing an
enchanted crescent blade, hurled through enemy ranks and recalled by an ancient
lunar spell, cutting on both outward flight and return.

No earlier tower image was supplied to the generator. The written image-generation
instructions supplied the style and production constraints. The only edit inputs
were the preceding stages newly created for this commission.

## Complete family

| File | Cumulative addition |
| --- | --- |
| `tier-1.png` | Stone pedestal, docked crescent, iron cradle and relic cloth. |
| `tier-2.png` | Two substantial iron braces supporting the cradle. |
| `tier-3.png` | Paired stone recall uprights with restrained lunar seals. |
| `tier-4-reaping-arc.png` | Bronze-faced fixed crescent launch vanes; outward-cut visual specialization. |
| `tier-4-oathbound-return.png` | Stone reliquary arch and violet keystone; recall visual specialization. |

Both final branches derive independently from the same completed tier 3. These
are art specializations, not new gameplay rules or balance changes. The blade is
shown docked; no flying projectile or temporary attack effect is baked into a sprite.

## Palette, placement and inspection

- All five final sprites are **1254 x 1254 RGBA PNGs**, the generator's native output
  dimensions. Production sprites were not resized or recentered.
- Shared registration origin: **(626.5, 1120)**, measured from the pedestal cap
  at y=800 (x=438 through x=815) and the lowest visible base pixel. Every final sprite has the same
  pedestal and visible ground contact; upgrade layers preserve the original core.
- `palette.json` records the exact **16 RGB colors** and their material roles,
  chosen before generation. Transparency is separate.
- `family-review.png` compares all stages on a dark background and at 160-pixel
  canvas size on a light background. Review previews alone are scaled.
- `alignment-preview.webp` switches all five stages at a fixed placement.
- `verification.json` records saved-file palette membership, alpha preservation
  in the final sweep, ground measurements, and unchanged visible parent pixels.

## Sources, locked layers and reproducibility

The exact final prompt set is in `prompts/`. All original ImageGen outputs are
in `sources/`; `layers/` and `masks/` retain the extracted upgrade additions.
`tier-1.png` is the palette-enforced locked base.

`build_family.py` performs only the processing authorized by the image-generation
instructions: deterministic color conversion, selection of generated additions,
locked-layer assembly, final palette restoration, and review composition. It does
not draw replacement tower artwork. It needs Python, Pillow and NumPy.

Run its commands in order: `base`, `tier-2`, `tier-3`, `branches`, `finish`.
The final color-only sweep restores the first tower's exact visible material pixels
through the complete family, preserves each finished alpha channel, saves, then
reopens every final sprite to check its RGB values. Every visible pixel from each
preceding stage is identical in its successor. The generator's alpha values below
16 are treated as faint background residue when selecting additions; the complete
base source remains preserved beneath the added layers. No alpha thresholding is
performed during palette conversion.

The raw return-branch generation moved the old structure downward. Its old
structure was discarded: the final image uses only the new arch over the original
unaltered tier-3 assembly, which avoids that shift.

`moonwheel-all-tiers.zip` packages the five final PNGs, palette, prompt set, placement
documentation, review and verification. This folder contains authoring artwork;
it is excluded from Godot imports with `.gdignore`.

## Runtime installation

All five final PNGs are copied unchanged into `assets/artwork/tower/moonwheel/`.
Tiers 1-3 keep their corresponding filenames. `tier-4-reaping-arc.png` supplies
`4/reaper_wheel.png`; `tier-4-oathbound-return.png` supplies `4/orbit_crown.png`.
Existing branch IDs, names, progression, saves and attack behavior are preserved.

The shared artwork catalog marks all five entries authored and uses 20 pixels per
world unit, canvas bounds `[-31.325, -56, 62.7, 62.7]`, and the measured ground
anchor `(626.5, 1120)`. Per-stage portrait framing includes the full silhouettes.
The existing cached texture cleanup removes alpha below 16 at runtime without
modifying any PNG. Authored images stay active at high zoom and native rebaking
preserves them. Returning blades launch from source pixel `(550, 500)`, mapped to
world muzzle `(-3.825, -31)` through the shared projectile profile.

Run `./launch.ps1 -TestScript tests/rendered/moonwheel_art_runner.gd` for source
identity, ground/muzzle mapping, outward/return flight, all tiers at normal/high
zoom and export rendering, compact portraits, and the three portrait phone sizes.
