# Baked campaign map artwork

The campaign map loads six PNG textures from `assets/campaign/baked/`. Each
540 × 1920 image contains a 540 × 960 chapter background above the same chapter
with gold completed roads. Ground, scenery, roads, water and bridges are all
baked. Chapter headings, level names, status text and interactive destination
buttons remain live, including locked, current, cleared and boss appearances.

The existing Chapter `map_landscape` component assigns the texture through its
presentation recipe in `scripts/content/catalogs/chapter_maps.gd`. Imported
textures are shared across map instances. Normal drawing takes one texture
rectangle per chapter, plus one partial rectangle for the current chapter's
completed trail. Map construction and resizing do not search for scenery sites,
draw scenery primitives, or calculate bridge intersections.

Images stretch horizontally with the viewport; marker positions use the same
normalized horizontal coordinates and unchanged vertical spacing. The baker
reserves the union of live labels and touch targets at upright widths 280, 320,
360, 390, 430, 540 and 768. Scenery may reflow during baking to keep those spaces
clear. No text or clickable destination artwork is baked into the background.

## Regenerating artwork

Run Godot with a rendering driver from the project root:

```powershell
& $GodotPath --path . --script res://tools/bake_campaign_maps.gd
& $GodotPath --headless --path . --editor --import
```

Use the project's isolated `.runtime/tests` APPDATA and LOCALAPPDATA folders,
as in `launch.ps1`. The baker needs GPU rendering; do not pass `--headless` to
the first command. It draws the existing reusable art recipes offline, without
changing gameplay or requiring an image-generation service. Re-bake after
changing chapter art recipes, map geometry, fonts or label reservations. Commit
all six PNGs and the generated `layout.cfg` clearance fixture together.

The six RGBA8 textures occupy about 23.7 MiB uncompressed in graphics memory
(without mipmaps). This replaces repeated procedural work with shared texture
memory. The six sections avoid a single texture taller than common mobile
texture limits.

## Validation

Run `tests/rendered/campaign_map_runner.gd`,
`tests/rendered/campaign_landscape_runner.gd`,
`tests/rendered/baked_map_runner.gd` and
`tests/rendered/campaign_map_menu_runner.gd` with a rendering driver. The first
two capture all six chapters at 360, 390 and 540 pixels wide. The baked-map test
checks rendered progression pixels against both halves of each atlas and
verifies shared texture reuse. Inspect the generated portrait captures as well.
Physical iPhone and Android loading time remains a device acceptance check.
