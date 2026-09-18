# Image generation instructions

These rules apply to any tower family. Choose its structure, materials and
upgrade features to fit its function. Do not impose features from another
tower design.

## Art style

Build the tower from a small number of large, clearly readable structural shapes.
Use bold black outer contours and dark separations between major components.
Describe each material with two or three broad, flat shading planes and occasional
angular highlights. Keep construction lines, ornament, and surface damage sparse.
Add only subtle weathering after the tower's main shapes already read clearly.
Preserve a strong silhouette at thumbnail size, and show upgrades through distinct
structural additions rather than extra surface detail.

Keep the rendering illustrative and two-dimensional, with matte materials and
crisp edges. Avoid photorealism, glossy 3D, smooth gradient shading and dense
surface texture. Each visible detail should help explain the tower's structure
or function; leave broad surfaces quiet.

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

## Final palette sweep across all five towers

After generating all five towers, run one final deterministic color sweep across
the complete set. Compare the shared base structure in every image and normalize
its shared materials and shadows to the same selected color assignments.
Update the base structure's colors in all five images, including tier 1,
so upgrades do not introduce lighter stone or different shades of the same material.
Using the same list of allowed colors is not enough: corresponding materials
must use the same color assignments throughout the set.

Preserve each tier-four branch's designated accent colors on its added features
that distinguish its specialization. These are exceptions to the common
material assignments, not exceptions to the 16-color limit. Reserve those accents
within the family's selected palette, and do not let them recolor the shared base.

Finish by checking all five images side by side and verifying their pixel colors.
The common tower should match across the set, while the two final branches retain
their distinct accents. Preserve geometry, alignment and transparency during
this final color-only pass.

## Position and progression

Keep every image centered on the same core structure and ground anchor, using
the same canvas size, camera and scale. Towers face straight toward the viewer,
with the same front-facing orientation throughout. Do not recenter images around
added features or decorations.
Check alignment by switching or overlaying the images; upgrades must not jump.

**Run an offset check on every image in a related set before delivery.** For a
five-stage tower set, check all five images. Measure and
verify that every image uses the same core center point and ground anchor at
the same pixel coordinates. Correct any horizontal or vertical offsets without
resizing or redrawing the artwork. Switch through every image at one fixed
placement to confirm they line up without shifting when the tower upgrades.

Build each upgrade from the previous base: tier 1 is basic, tier 2 adds functional
improvements, and tier 3 develops those improvements further. Both tier-four
branches build independently from tier 3.
Add to the structure without changing its core width or shifting its fixed features.

Distinguish tiers through clear additions that suit the tower's function.
Each stage should visibly build on the previous one. Make each branch's identity
clear with a few bold features rather than many tiny details.

## Generate upgrades by editing the previous image

Generate the tier-one tower first. For every upgrade, supply the actual image
from the preceding stage as the edit source and add the new features to it.
Do not generate each tier independently from a text description.

- **Finish tier 1 first.** Approve its stone, roof, timber, lighting and palette
  before generating any upgrades.
- **Keep the shared structure on a locked base layer.** Use the actual approved
  tier-one image as the base layer for every upgrade, preserving its pixels.
  Generate upgrade additions, retain only those additions using masks, and
  composite them on top of that base layer. Keep previous upgrades as additional
  layers as the tower progresses. The base image must remain intact beneath
  the additions; using it only as a generation reference or accepting a repainted
  version of the shared structure does not satisfy this requirement.

1. **Tier 1:** Create the basic tower image.
2. **Tier 2:** Use the tier-one image and add the requested tier-two features.
3. **Tier 3:** Use the completed tier-two image and add the requested tier-three features.
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

Make structures believable for their purpose. Support heavy components and keep
their functional parts clear and usable. Any attack source must suit the design.
Do not bake flying projectiles or transient attack effects into static tower
artwork. Gameplay attacks should originate from the intended source without
passing through solid structure. Include only features appropriate to the
specific tower being designed.

Give towers a small, low buildup of chunky, crumbly stone at the base so they
blend into the ground. Keep functional areas clear and avoid oversized rubble mounds.
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

## Required last step: restore the first tower's colors across the set

At the very end, return to the completed, palette-enforced tier-one image.
Its base-material colors are the authority for the rest of the towers. Do not
let colors introduced in later generations redefine the original tower's palette.

Run a deterministic script over all five finished images in order: tier 1,
tier 2, tier 3, then both tier-four branches. Remap the shared structure's colors
to the exact colors used for those materials in tier 1. Enforce an explicit list
of allowed RGB values so no extra shades remain. Match material assignments as
well as palette membership; a shared surface should not change color between tiers
just because both colors are on the allowed list.

Only the designated branch additions may retain their reserved accent colors.
Those accents must already belong to the selected 16-color family palette;
they must not alter the shared base structure or expand the palette.

After saving, reopen all five files and verify every nontransparent pixel against
its allowed palette. Check the shared materials against tier 1 and inspect the
set together. Preserve dimensions, positions, shapes and transparency throughout.
Correct remaining color mismatches with the script, without regenerating images.
Do not deliver the set until this final saved-file check passes.
