# Rift types

Each rift uses the style of its source tile. Every enemy type receives the same
source effect and retains it along its entire route; crossing other tiles never
adds or replaces an effect. The core remains free of rifts.

| Terrain | Rift | Default effect | Visual motif |
| --- | --- | --- | --- |
| Forest / grass | Wild | None, everywhere | Woodland stone and leaves; no enemy marker |
| Ashen Forge | Forged | +25% maximum health | Riveted plates and a small shield |
| Drowned Crypt | Drowned | +15% movement speed | Curling water and a current mark |
| Bloodmoon Sanctuary | Bloodmoon | Heal 1% of maximum health per second | Crystal spires and a crescent |

Settings → Developer Controls → Rifts selects the three adjustable effects.
Each strength ranges from 0 to 100 percent in 0.25-point steps; zero disables it.
For Bloodmoon the percentage is healing per second. Changes apply to existing
and future enemies and auto-save with the current game. Health changes preserve
remaining health percentage. Selected-type and global resets restore defaults.
Grass is intentionally not adjustable. Existing saves without overrides use the
defaults, and saved terrain styles remain unchanged.

Regeneration stops at full health and cannot revive a dead enemy. Speed bonuses
multiply base enemy speed before slows and stuns. Rewards and spawn rates retain
their existing settings. Rift art and enemy markers share native flat polygons,
palette colors and black outlines with the terrain and actors; they need no
particle nodes and remain static for reduced-motion accessibility.

Run `./launch.ps1 -Check` for regression coverage. The rendered
`res://tests/rendered/rift_preview.gd` script produces an art comparison and checks
rift controls at narrow and standard phone sizes.
