# App icon

The app uses `icon.png`: an opaque 1024 × 1024 RGB PNG. `project.godot` selects `res://icon.png`; the Android, Android Tablet and iOS export presets inherit this asset.

Updated September 16, 2026 to match the user's Pickard menu and tier-one tower references. Pickard's closed angular iron helmet and black visor dominate a close-up portrait, with faceted armor, a muted red cloak and an aged-metal clasp. A parchment moon separates the silhouette from charcoal-green ruins. This replaces the earlier purple watchtower icon and follows [ART_DIRECTION.md](ART_DIRECTION.md).

The source is full bleed with no baked rounded corners, outer frame or transparency. The helmet and visor stay central for circular and rounded-square launcher masks; the shoulders extend toward the lower edges. This static branding asset is independent of gameplay drawing components. An app rebuild and installation are required to update phone home-screen icons; desktop import and simulated mask checks do not verify installed mobile builds.

## Reference roles

- [Pickard menu artwork](../assets/ui/pickard-menu-background.png): character identity, moonlit palette and mood.
- [Tier-one towers](references/tier-one-towers-art-reference.png): angular material facets, strong black contours and restrained weathering. Its text and catalog layout are not icon elements.

## Generation prompt

Mode: built-in image generation using the two supplied reference images, followed by size normalization to 1024 × 1024 RGB. The prompt used was:

Use case: style-transfer.
Asset type: production mobile app icon for Pickard / Hollow Vigil.
Primary request: Transform the supplied Pickard menu artwork into one finished square app icon matching the art identity of both supplied references.
Input images: Image 1 is the character and palette source to recompose into an icon; Image 2 is supporting style reference only, for angular iron/stone facets, bold black contours, muted cloth and sparse pale diamond heraldry. Do not reproduce its text, grid or tower catalog.
Subject and composition: A bold, centered close-up bust of Pickard, helmet and upper shoulders, facing forward. Preserve his closed angular iron helmet with its distinctive black T-shaped visor and strong central ridge; broad weathered faceted gray armor and muted dark red cloak secured by a simple aged-metal clasp. The helmet is the dominant instantly recognizable shape. A pale parchment moon behind the helmet separates the silhouette from the deep charcoal-green night. Simplify background to very restrained angular dark-green ruins near the outer lower edges. Shoulder and cloak shapes may extend to bottom edge, with a small pale diamond clasp detail if useful.
Style: Match the supplied hand-painted angular 2D fantasy game illustrations closely: heavy near-black contour, large clear planes of warm iron gray and parchment highlights, weathered red cloth, subtle restrained grain. Strong readable silhouette, minimal fine decoration, quiet moonlit mood.
Framing: 1024x1024 square, full-bleed opaque artwork to all four straight edges. Center essential helmet, visor and clasp within the central 65 percent so circular and rounded-square launcher crops retain them. Helmet fills about the central half of image width, shoulders about three quarters; keep top of helmet comfortably inside the circle crop. No full-body figure.
Avoid: text, letters, wordmark, labels, interface elements, grid, outer frame, baked-in rounded corners, transparency, bright purple, pastel green, gold crown, glow, gradients, glossy 3D, photorealism, decorative particles, excessive tiny details.
Output one finished square icon only, not a mockup or contact sheet.
