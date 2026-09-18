# Ash Needle: new tier-one tower

Created with the built-in ImageGen tool following
[the image generation instructions](../../IMAGE_GENERATION_INSTRUCTIONS.md)
and [the app art theme](../../APP_STYLE_THEME.md).

The design uses a pointed slate roof over a timber arrow gallery, an ash-stone
shaft, a small oxblood diamond banner, a usable door and low rubble. Two black
firing openings remain clear. The sprite contains no projectiles or attack effects.

- **Finished asset:** [tier-1.png](tier-1.png), 1024 x 1536 RGBA.
- **Placement:** core center x=512; measured ground anchor (512, 1354).
- **Palette:** [palette.json](palette.json) records sixteen selected colors and
  their roles. This tier uses thirteen; three are reserved for potential frost
  and poison upgrades.
- **Prompt:** [prompt.txt](prompt.txt) records the exact generation request.
- **Verification:** [verification.json](verification.json) records reopened-file
  RGB membership, source/final hashes, dimensions and identical alpha.
- **Visual review:** [review.png](review.png) shows light/dark backgrounds and
  64-, 96- and 128-pixel-wide thumbnails. It is a diagnostic image, not a sprite.

`generated-source.png` preserves the original output. Run
`python enforce_palette.py generated-source.png` from this directory with Pillow
and NumPy installed to reproduce the final color-only palette conversion and
review. No dithering, resizing, translation or alpha changes are applied to the
finished sprite. Material-aware mappings keep wood, cloth, stone and the bone
insignia in their assigned colors. Only the diagnostic review contains resizing.

This delivery is a new tier-one design. It does not replace the live Gloamwatch
artwork or alter the game catalog. Future upgrades should preserve `tier-1.png`
as the locked base, follow the cumulative five-sprite progression, and share its
canvas, palette and measured anchor.
