# Gloam arrow tower: original redesign

Generated with the built-in ImageGen tool from `docs/IMAGE_GENERATION_INSTRUCTIONS.md`.
No old or current Gloam artwork was supplied as a visual reference. Architecture:
a broad timber firing loft over a compact stone watchpost, a shallow roof, black
firing apertures and a usable central door. No occupants or arrows are baked in.

## Selected family palette

| RGB | Role |
| --- | --- |
| #000000 | Outline and window voids |
| #18221F | Deep green shadow |
| #303C35 | Dark stone |
| #50584D | Stone shadow plane |
| #747669 | Stone front plane |
| #92917E | Worn stone edge |
| #252D2C | Roof shadow |
| #46514B | Roof face |
| #352A24 | Timber shadow |
| #66503B | Timber face |
| #452A2B | Cloth shadow |
| #77463E | Oxblood cloth |
| #B7AA89 | Bone heraldry |
| #587885 | Frost shadow |
| #A1BAC0 | Frost face |
| #70844A | Poison green |

Transparency is separate from this sixteen-color palette.

## Delivery and placement

All five final sprites are 1024 x 1536. Their doorway centers and ground-contact
anchors align at (512, 1352), using integer translation without resampling or
clipping any nontransparent pixels. The projectile outlet is (512, 702), inside
the black central opening in every stage. Runtime scale remains 20 pixels per
world unit; catalog origin is (-25.6, -67.6), with the outlet at (0, -32.5).

`verification.json` records reopened-file palette and anchor checks. The full
set uses exactly the selected sixteen RGB values; each stage uses a subset.
`family-preview.png` shows the five stages together. Prompt files record the
base generation and subsequent edits. Both final branches use tier three as
their image source.

`tools/gloam_renewed_palette.py` assigns the same material colors to every stage,
preserving source alpha. `tools/gloam_renewed_delivery.py SOURCE_DIRECTORY`
runs the final palette pass, aligns the entrance, validates saved sprites and
copies them into `assets/artwork/tower/rapid/`. Source files must be named
`level-1.png`, `level-2.png`, `level-3.png`, `tier-4-frost.png` and
`tier-4-poison.png`. Generated sources for this run remain in the local ignored
`artifacts/gloam-renewed-source/` directory.
