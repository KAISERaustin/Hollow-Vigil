# Caltrop Keep — The Sapper's Hold

Original five-sprite family, created September 20, 2026 with the built-in image_gen tool. The user's Caltrop Keep description is the sole subject/design source. No previous tower images were viewed or supplied to ImageGen. Repository image-generation documents provided rendering and production requirements.

## Deliverables

| File | Stage | Added function |
| --- | --- | --- |
| `tier-1.png` | Tier 1 | Squat stone hold, supply door, central iron caltrop trough |
| `tier-2.png` | Tier 2 | Two loaded side supply bins |
| `tier-3.png` | Tier 3 | Hand-cranked replenishment hoist and suspended caltrop basket |
| `tier-4-broadscatter.png` | Tier 4A — Broadscatter Arsenal | Supported broad distribution trays with bronze fittings |
| `tier-4-ironthorn.png` | Tier 4B — Ironthorn Hold | Heavy caltrop storage rack and muted red identification pennants |

The two tier-4 branches independently retain tier 3. These are art concepts; branch names and visual specializations do not introduce gameplay rules or balance changes. This task does not install the family in runtime.

## Shared placement

All final sprites are **1254 × 1254 RGBA PNGs**, at their generated native dimensions, without resizing. Core centerline **x = 627**; shared ground anchor **(627, 1122)**. The tier-one silhouette bounds are **(217, 679, 1037, 1123)**, using exclusive right/bottom bounds. Do not recenter around the overall silhouette of later tiers.

The prompt initially requested 1024 square. The tool returned 1254 square; all subsequent edits and deliverables use the actual native size. The raw Ironthorn generation moved the structure; only its new rack/pennant layer was translated **(-1, -55)** before assembly. No base artwork was moved or rescaled.

## Palette

One palette was selected and recorded before generation. Transparency is separate.

| RGB | Role |
| --- | --- |
| `#000000` | outer ink |
| `#141A18` | recesses |
| `#29302B` | stone deep shadow |
| `#43483D` | stone shaded plane |
| `#666957` | stone front |
| `#888974` | stone top edge |
| `#262B2F` | iron shadow |
| `#485457` | iron body |
| `#7D8B89` | iron lit face |
| `#A8AEA0` | iron point |
| `#312922` | timber shadow |
| `#584735` | timber face |
| `#806544` | bronze shadow, tier 4A fittings |
| `#AA8855` | bronze face, tier 4A fittings |
| `#502C2B` | cloth shadow, tier 4B pennant |
| `#81433A` | cloth face, tier 4B pennant |

Tier 1–3 use 12 colors; each branch uses 14; the full family uses the selected 16. Bronze exists only on new Broadscatter attachments; red exists only on new Ironthorn attachments.

## Production and verification

`sources/` holds the unmodified ImageGen returns. `layers/tier-1-locked-base.png` is the palette-enforced base. Each upgrade retains **every nontransparent pixel of its parent verbatim** and admits only masked ImageGen additions in previously transparent areas. Individual layer/mask PNGs are retained. No part of the base or previous tiers is replaced by a regenerated version.

The cutout isolation mask removes generated background residue with alpha at or below 4/255. This precedes palette conversion; palette conversion preserves alpha exactly and introduces no dithering. All final saved files were reopened, checked against the selected RGB list and compared with the authoritative tier-one base and their immediate parent. All five report zero core offset and zero base pixel mismatches.

Run `verify_family.py` with Python, Pillow and NumPy for the final palette sweep, saved-file checks and inspection outputs. `validation.json` records hashes and results. `family-review.png` shows all five at identical scale and at a 96-pixel base width. `alignment-preview.webp` switches through them at one unchanged placement. Preview backgrounds, text and downscaling are presentation only, not sprite content.

Exact prompts: [prompts.md](prompts.md). Palette: [palette.json](palette.json). Layer extraction regions and translations: [assembly.json](assembly.json).

Validation covers these art assets, palette, alpha, layer preservation and alignment. No device or gameplay validation is claimed.
