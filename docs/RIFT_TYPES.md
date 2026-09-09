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

In Campaign Creative, **Menu → Edit rules → Rifts** edits the three adjustable effects. Strength ranges from 0 to 100 percent in 0.25-point steps; zero disables an effect. For Bloodmoon, the value is healing per second. Apply commits the draft configuration. Health changes preserve remaining health percentage. Selected-type and global resets restore defaults. Forest uses its authored default.

Regeneration stops at full health and cannot revive a dead enemy. Speed bonuses
multiply base enemy speed before slows and stuns. Rewards and spawn rates retain
their existing settings. Rift art and enemy markers share native flat polygons,
palette colors and black outlines with the terrain and actors; they need no
particle nodes and remain static for reduced-motion accessibility.

Run `./launch.ps1 -Check` for Campaign simulation, terrain rendering and portrait control coverage.
