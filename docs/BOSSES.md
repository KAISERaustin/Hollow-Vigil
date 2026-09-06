# Stone-cluster bosses

Every deterministic four/five-tile hidden stone cluster has one boss in its
first generated cell. Its type is seeded separately, with all four types
available regardless of the territory's rift biome. Buying that cell summons
the boss immediately; buying other cells does not. Revealed boss cells in
older saves awaken once on loading this version.

Bosses wander along owned curved roads, excluding the core whenever any other
owned exit exists. Junction choices vary with their step count and avoid an
immediate reversal where possible; even backtracking is preferred to the core.
Only when the core is the sole exit do they enter it and escape, ending that
cluster's encounter without a bounty. They never pass through it to keep roaming.
Newly purchased roads become available at junctions. A new alternative or a
legacy save can reverse an inbound core leg along the same road without warping.

| Boss | Health / speed / gold | Ability and level-four counter |
| --- | --- | --- |
| Briarbound Warden | 3200 / 27 / 450 | 600-point root shield never regenerates. Cinderfield ground damage deals double shield damage. Excess damage passes into health without doubling. |
| The Cinder Reliquary | 3600 / 25 / 500 | Takes 30% less damage above half health. At half health loses armor and gains 70% speed. Frostneedle deals 50% extra damage, suppresses haste while chilled, and retains its usual 25% slow. |
| The Drowned Bell | 2800 / 32 / 450 | Summons three Hollows every 8 seconds, capped at six live escorts per bell. Thunderseal's detonation bonus is 50% stronger and delays the next toll by 2 seconds, once per toll. Escorts grant no gold. |
| The Eclipse Prior | 3000 / 30 / 500 | Three wards each absorb one damage event; refill every 10 seconds. Doomstone bypasses wards and retains its normal damage stacks. A fully stacked curse pauses ward regrowth while its tower maintains that target in range and is not rebuilding. |

Boss health, road position, current leg, defenses, ability timers, and completed
encounters are saved. Offline time does not damage or move a boss. Transient
projectiles, slows, stuns and tower curses restart with ordinary combat on
reload. Defeated or escaped bosses cannot respawn. Boss and escort
rewards do not feed repeating offline income. Rift biome bonuses and developer
enemy tuning apply to ordinary enemies, not bosses.

Native flat artwork uses the terrain, portal and enemy palette and line style.
The Warden and Cinder Reliquary float without limbs. Boss titles use parchment
nameplates and shared serif typography; weakness labels are removed from the map.
Health bars, root shields and visible crystal wards remain. Artwork renders at
0.51 scale, 15% smaller than the previous 0.6 scale. The internal `cindermaw` key
is retained for save and encounter compatibility.
The model lives in `scripts/gameplay/encounters/bosses.gd`; artwork in
`scripts/rendering/actors/boss_art.gd`. Run `./launch.ps1 -Tests` for encounter checks
and `./launch.ps1 -ArtSmoke` for the lineup and six battlefield captures.
The initial health, speed and reward values are balance starting points.
