# Replaceable actor images

Each ordinary enemy, tower tier, tower specialization, and Ironspike bow has its
own transparent PNG under `assets/artwork/`. These are individual source images,
not cells in a shipped sprite sheet. Matching instances reuse a loaded texture.
The current PNGs are rendered from the existing native artwork, preserving its
silhouette, palette, proportions and outline geometry.

`assets/artwork/catalog.json` maps presentation keys to image paths, world-space
bounds and pixels per world unit. It contains no combat statistics. Both modes,
build previews and menu portraits use the shared image renderer. Health bars,
afflictions, charges, curse stacks, rebuilding, earnings, projectiles and boss
animation remain with their existing dynamic drawing owners.

## Replace an image

1. Find its entry in `assets/artwork/catalog.json` and open the indicated PNG.
2. Replace the PNG, preserving transparency, dimensions and the foot/socket
   position. Godot imports the replacement. Restart the running game preview.
3. If the new image needs a different canvas, update `bounds` and
   `pixels_per_unit` in that entry. Bounds are `[left, top, width, height]` relative
   to the enemy's feet or tower's socket, in world units. Keep adequate clear
   margins around outlines.
4. Inspect its portrait, overlapping battlefield objects, and 360×640, 390×844
   and 540×960 upright portrait views, including minimum zoom and 1.65× zoom.

The shipped enemy canvases are 96×96 pixels; tower and bow canvases are 192×192.
Their resolution is two pixels per world unit. Generated native entries use the
original vector renderer beyond that resolution for unrestricted developer zoom.
For custom images, remove `native_fallback_above_zoom` from their entries so the
replacement also remains visible at unrestricted developer zoom. Supply a
higher-resolution PNG with the same world bounds when close inspection needs
more detail. At ordinary supported zoom levels the images are always used.

Ironspike uses two independently replaceable images. Its bow rotates around the
existing projectile muzzle; its pedestal remains fixed. Keep the bow's canvas
and anchor aligned with the pedestal when editing it. No angle-specific image
copies are needed.

## Add artwork

Add a PNG and a catalog entry using `enemy/<kind>`,
`tower/<kind>/<level>/<branch>` or `bow/<kind>/<level>/<branch>`.
For tiers without a specialization, the key ends in `/`, for example
`tower/rapid/1/`. The new content itself must still follow `NODE_SYSTEM.md`;
an artwork entry never creates a playable enemy or tower or changes balance.
Unregistered presentation keys retain the native drawing fallback.

The catalog is explicitly included in every export preset. Images are ordinary
Godot texture resources, with lossless import and mipmaps for distant views.
Canvas owners release their texture references when freed. Godot shares the
underlying resources between owners, so repeated enemies do not allocate new
textures. Cache data is absent from saves.

## Regenerate native defaults

Run a rendering-capable Godot executable with
`--path . --script res://tools/bake_actor_images.gd`, then import the project.
The baker creates missing images and catalog entries and preserves existing
files, including replacements. Only pass `-- --overwrite-native` when you
explicitly intend to regenerate existing native PNGs. It never uses gameplay
randomness. The validation helper enables mipmaps on the generated image imports.

The intermediate drawing surface exists only while baking. It is split into
individual PNGs and is not shipped or loaded by the game.
