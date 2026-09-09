# Enemy artwork

All eighteen ordinary enemies use native Godot filled shapes and black outlines. Their six distinct biome rosters are listed in [PORTAL_ROSTERS.md](PORTAL_ROSTERS.md).

`VigilEnemyArt.draw` reads the enemy node's assigned presentation renderer. Classic shapes live in `enemy_art.gd`, the seven new Forge/Crypt/Sanctuary silhouettes in `themed_enemy_art.gd`, and the three Orchard silhouettes in `orchard_art.gd`. `VigilTerrainArt.enemy` remains the battlefield entry point. Menus and generated portraits call the same native drawing code.

Forest uses moss, leaves and bark; Forge uses coal, iron and embers; Crypt uses reeds, shell masks and a sunken bell; Sanctuary uses prayer robes, crescents and a crimson knight. Castle inhabitants use dark royal stone and armor; Orchard inhabitants use thorn wood, burial veils and rooted coffins. Every silhouette stays inside the shared road footprint and below its health bar. Presentation assigns reusable death sounds independently from statistics.

Developer controls read the same definition as combat. Optional future capabilities belong to attachable components; these drawings add no hidden buffs or timed status effects.

The transparent reference PNGs in `assets/enemies/` show the native artwork. Gameplay draws the shapes directly. Campaign terrain and illustrated-picker tests cover their current rendering and portrait integration.
