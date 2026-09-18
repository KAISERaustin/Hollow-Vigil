# Image generation instructions

These rules apply to any tower family. Choose its structure, materials and
upgrade features to fit its function. Do not impose features from another
tower design. Follow the requested number of tiers and upgrade branches;
these instructions do not prescribe a particular progression layout.

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
materials suited to the design, such as weathered stone, worn iron, dark timber
or heavy cloth, with restrained supernatural features where appropriate.
Shapes and materials should suggest age, hardship and endurance.

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
the design's materials and accents. Include those values in the generation prompt
and use only those colors in the finished image. Do not inherit a palette from
an unrelated piece or introduce extra shades during generation.

For a related set, such as a tower's upgrade stages, choose one 16-color palette for
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

## Final palette sweep across the complete set

After generating every requested stage, run one final deterministic color sweep
across the complete set. Compare the shared base structure in every image and normalize
its shared materials and shadows to the approved base image's color assignments.
Preserve the approved base layer in every image; correct any deviations in the
assembled set without changing that layer's colors. Upgrades must not introduce
lighter shared surfaces or different shades of the same material.
Using the same list of allowed colors is not enough: corresponding materials
must use the same color assignments throughout the set.

Preserve each upgrade branch's designated accent colors on its added features
that distinguish its specialization. These are exceptions to the common
material assignments, not exceptions to the 16-color limit. Reserve those accents
within the family's selected palette, and do not let them recolor the shared base.

Finish by checking every image side by side and verifying its pixel colors.
The common tower should match across the set, while any upgrade branches retain
their distinct accents. Preserve geometry, alignment and transparency during
this final color-only pass.

## Position and progression

Keep every image centered on the same core structure and ground anchor, using
the same canvas size, camera and scale. Towers face straight toward the viewer,
with the same front-facing orientation throughout. Do not recenter images around
added features or decorations.
Check alignment by switching or overlaying the images; upgrades must not jump.

**Run an offset check on every image in a related set before delivery.** Include
every requested stage and branch. Measure and verify that every image uses
the same core center point and ground anchor at the same pixel coordinates.
Correct any horizontal or vertical offsets without
resizing or redrawing the artwork. Switch through every image at one fixed
placement to confirm they line up without shifting when the tower upgrades.

Build each upgrade from its preceding stage, adding functional improvements
cumulatively. When progression branches, build each branch independently from
its specified shared parent stage.
Add to the structure without changing its core width or shifting its fixed features.

Distinguish tiers through clear additions that suit the tower's function.
Each stage should visibly build on the previous one. Make each branch's identity
clear with a few bold features rather than many tiny details.

## Generate upgrades by editing the previous image

Generate the tier-one tower first. For every upgrade, supply the actual image
from the preceding stage as the edit source and add the new features to it.
Do not generate each tier independently from a text description.

- **Finish tier 1 first.** Approve its structure, materials, lighting and palette
  before generating any upgrades.
- **Keep the shared structure on a locked base layer.** Use the actual approved
  tier-one image as the base layer for every upgrade, preserving its pixels.
  Generate upgrade additions, retain only those additions using masks, and
  composite them on top of that base layer. Keep previous upgrades as additional
  layers as the tower progresses. The base image must remain intact beneath
  the additions; using it only as a generation reference or accepting a repainted
  version of the shared structure does not satisfy this requirement.

1. **Base stage:** Create and finish the basic tower image.
2. **Each subsequent stage:** Use the completed preceding stage and add only
   the requested upgrade features on separate layers above the locked base.
3. **Each branch:** Start from its specified shared parent stage and add that
   branch's features. Do not build one sibling branch from another.

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

Run a deterministic script over every finished image, starting with the approved
base stage and then covering all requested upgrades and branches. Correct any
shared-material color deviations to the exact colors used in the approved base,
preserving the locked base layer. Enforce an explicit list of allowed RGB values
so no extra shades remain. Match material assignments as
well as palette membership; a shared surface should not change color between tiers
just because both colors are on the allowed list.

Only the designated branch additions may retain their reserved accent colors.
Those accents must already belong to the selected 16-color family palette;
they must not alter the shared base structure or expand the palette.

After saving, reopen every file and verify every nontransparent pixel against
its allowed palette. Check the shared materials against tier 1 and inspect the
set together. Preserve dimensions, positions, shapes and transparency throughout.
Correct remaining color mismatches with the script, without regenerating images.
Do not deliver the set until this final saved-file check passes.
