# Image generation instructions

## Art style

Create stylized 2D dark medieval fantasy: bold black outlines, strong angular
silhouettes, chunky shapes and broad, flat color planes. Suggest depth with a
few hard-edged shadow facets rather than smooth gradients. Materials should
feel matte and worn: heavy stone, dull iron, dark wood and simple cloth.

Keep details sparse and readable at small game sizes. A few large seams or chips
are enough; avoid tiny brick patterns, elaborate trim and busy surface texture.
The mood is somber, ancient and watchful. Avoid photorealism, glossy 3D, bright
cartoon colors, neon and excessive glow.

## Dark fantasy theme

Every image must feel like it belongs in a dark medieval fantasy world. Favor
weathered stone, worn iron, dark timber, heavy cloth and restrained supernatural
features. Shapes and materials should suggest age, hardship and endurance.

Keep the mood somber, mysterious and watchful. Use deep shadows and muted colors
while keeping the subject readable. Magic and elemental features should support
the subject's identity without overwhelming it with bright effects. Avoid cute,
playful, modern or futuristic elements that break the setting.

Check both appearance and purpose: the subject should look at home in this world
and function believably within it. Dark fantasy should come from the design,
materials and atmosphere, not simply making the entire image too dark to see.

## Color

**Select a palette of 16 colors specifically for the piece before generating it.**
Record the exact color values and assign their roles, such as outline, shadow,
stone, wood, cloth and accents. Include those values in the generation prompt
and use only those colors in the finished image. Do not inherit a palette from
an unrelated piece or introduce extra shades during generation.

For a related set, such as five tower stages, choose one 16-color palette for
the entire set, including any colors needed by later upgrades. Each image can
use a subset of those colors. Keep shared materials the same color across all
images; an upgrade must not make the base structure lighter.

Favor dark, muted colors with small contrasting accents. Verify the finished
image's color values against the selected palette; specifying colors in a prompt
alone is not enough. Transparency is separate from the 16-color palette.

## Enforce the palette after generation

Expect ImageGen to introduce extra shades beyond the requested palette.
**Deterministic scripted palette conversion is explicitly allowed:** sweep over
the generated image and map its colors to the selected 16-color palette.
Use the same selected palette for every image in a related set.

This is a color-only correction. Preserve the image dimensions, pixel positions,
shapes and alpha channel; do not resize, redraw or add dithering that introduces
extra colors. Verify afterward that every nontransparent pixel uses one of the
16 selected RGB values, and visually check that material and accent colors still
read correctly. Individual images may use fewer than all 16 colors.

## Position and progression

Keep every image centered on the same core structure and ground anchor, using
the same canvas size, camera and scale. Towers face straight toward the viewer,
with the door facing forward. Do not recenter images around flags or decorations.
Check alignment by switching or overlaying the images; upgrades must not jump.

**Run an offset check on every image in a related set before delivery.** For a
five-stage tower set, check all five images. Measure and
verify that every image uses the same core center point and ground anchor at
the same pixel coordinates. Correct any horizontal or vertical offsets without
resizing or redrawing the artwork. Switch through every image at one fixed
placement to confirm they line up without shifting when the tower upgrades.

Build each upgrade from the previous base: tier 1 is basic, tier 2 adds supports,
and tier 3 is fortified. Both tier-four branches build independently from tier 3.
Add to the structure without changing its core width or shifting its doorway.

Use flags to help distinguish tiers: no flag on tier 1, a top flag on tier 2,
and an added front banner on tier 3. Final branches retain these and add a flag
matching their specialization. Make each branch's theme clear with a few bold
features rather than covering the tower in tiny details.

## Generate upgrades by editing the previous image

Generate the tier-one tower first. For every upgrade, supply the actual image
from the preceding stage as the edit source and add the new features to it.
Do not generate each tier independently from a text description.

1. **Tier 1:** Create the basic tower image.
2. **Tier 2:** Use the tier-one image and add supports, its flag and other
   requested tier-two features.
3. **Tier 3:** Use the completed tier-two image and add fortification, its banner
   and other requested tier-three features.
4. **First final branch:** Use the completed tier-three image and add this
   branch's features.
5. **Second final branch:** Start again from the same completed tier-three image
   and add the other branch's features. Do not build it from the first branch.

Preserve the existing structure and previous upgrades in each edit. New features
should visibly build onto the same tower while its core shape, scale, palette,
center point and ground anchor stay fixed. Keep the same canvas and reserved
space for additions; do not redraw or reposition the base to fit the upgrade.
Run the offset and alignment checks on the completed set, even when the correct
source images were used.

## Practical details

Make structures believable for their purpose: supported floors, usable doors
and clear firing openings. For archer towers, keep windows blacked out with no
visible occupants or bows. Do not bake arrows into the static artwork; gameplay
projectiles should appear to emerge from the windows, not pass through masonry.

Give towers a small, low buildup of chunky, crumbly stone at the base so they
blend into the ground. Keep the entrance clear and avoid oversized rubble mounds.
Isolated game assets need transparent backgrounds without rectangular residue
or halos, with enough margin for the complete silhouette and later upgrades.

## Revisions and checks

Preserve an approved design when making corrections: change only what was requested.
Position changes should move the existing artwork, not redraw it. Color changes
should preserve its shape and placement. Before delivery, inspect the whole
family together and at game size for palette consistency, alignment, readable
upgrades and clean transparency.

Treat these as requirements to verify in the finished images, not just wording
to include in a prompt. Deliver the selected palette and shared placement
coordinates with a related set so they can be reused consistently.
