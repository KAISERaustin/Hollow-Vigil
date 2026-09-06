# Stone-cluster bosses

Every deterministic four/five-tile hidden stone cluster has one boss in its
first generated cell. Its type is seeded separately, with all four types
available regardless of the territory's rift biome. Buying that cell summons
the boss immediately; buying other cells does not. Revealed boss cells in
older saves awaken once on loading this version.

Bosses patrol owned roads until defeated. They follow the actual curved road
spokes between adjacent tiles, avoid immediate reversal at junctions, take
periodic detours, and otherwise favor the core neighborhood. Dead ends cause
turnarounds. Crossing the core never counts as an escape. Newly purchased
neighbors become eligible at the next junction; a current road leg is stable.

| Boss | Health / speed / gold | Ability and level-four counter |
| --- | --- | --- |
| Briarbound Warden | 3200 / 27 / 450 | 600-point root shield regrows every 10 seconds. Cinderfield ground damage deals double shield damage and pauses regrowth while occupied. Excess damage passes into health without doubling. |
| Cindermaw | 3600 / 25 / 500 | Takes 30% less damage above half health. At half health loses armor and gains 70% speed. Frostneedle deals 50% extra damage, suppresses haste while chilled, and retains its usual 25% slow. |
| The Drowned Bell | 2800 / 32 / 450 | Summons three Hollows every 8 seconds, capped at six live escorts per bell. Thunderseal's detonation bonus is 50% stronger and delays the next toll by 2 seconds, once per toll. Escorts grant no gold. |
| The Eclipse Prior | 3000 / 30 / 500 | Three wards each absorb one damage event; refill every 10 seconds. Doomstone bypasses wards and retains its normal damage stacks. A fully stacked curse pauses ward regrowth while its tower maintains that target in range and is not rebuilding. |

Boss health, road position, current leg, defenses, ability timers and defeat
records are saved. Offline time does not damage or move a boss. Transient
projectiles, slows, stuns and tower curses restart with ordinary combat on
reload. Defeated bosses cannot respawn or pay a second bounty. Boss and escort
rewards do not feed repeating offline income. Rift biome bonuses and developer
enemy tuning apply to ordinary enemies, not bosses.

Detailed sprite artwork preserves the approved four-boss concept, with persistent
names, health bars, weakness labels, root shield bar and visible crystal wards.
The model lives in `scripts/model/bosses.gd`; artwork in
`scripts/rendering/boss_art.gd`. Run `./launch.ps1 -Tests` for encounter checks
and `./launch.ps1 -ArtSmoke` for the lineup and six battlefield captures.
The initial health, speed and reward values are balance starting points.
