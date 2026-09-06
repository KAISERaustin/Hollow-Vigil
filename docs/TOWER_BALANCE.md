# Tower levels and specializations

Every tower starts at level 1, upgrades through levels 2 and 3, then chooses one of two permanent level-4 branches. Click Upgrade at level 3 to open left and right choices. Selecting either opens its portrait and description above the buttons. A separate confirmation spends gold. Branch previews remain available without enough gold, but purchase is disabled. Level 4 is the maximum.

These are the default values. Developer Controls scale inherited stats and prices for the current save. Special effects scale with tuned hit damage; durations, distances, percentages, and charge limits stay fixed.

## Levels 1–3

| Tower | Level | Damage per hit | Interval (s) | Range | Blast radius | Individual price |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ashneedle | 1 | 6 | 0.48 | 132 | 0 | 60 |
| Ashneedle | 2 | 10 | 0.40 | 146 | 0 | 60 |
| Ashneedle | 3 | 15 | 0.30 | 160 | 0 | 100 |
| Pyre | 1 | 15 | 1.50 | 126 | 46 | 120 |
| Pyre | 2 | 24 | 1.30 | 140 | 56 | 120 |
| Pyre | 3 | 36 | 1.10 | 154 | 66 | 200 |
| Obelisk | 1 | 40 | 1.80 | 157 | 0 | 160 |
| Obelisk | 2 | 60 | 1.35 | 173 | 0 | 140 |
| Obelisk | 3 | 90 | 0.90 | 189 | 0 | 220 |
| Stormspire | 1 | 3 | 0.40 | 145 | 0 | 140 |
| Stormspire | 2 | 5 | 0.35 | 159 | 0 | 120 |
| Stormspire | 3 | 7 | 0.30 | 173 | 0 | 200 |

Prices are gold. Range and blast radius are world units. Stormspire strikes up to five distinct primary targets per pulse at every level. Pyre deals its blast damage to each enemy in the radius. Combat advances in 0.05-second ticks; intervals round up to the next tick, without adding an extra tick for floating-point residue.

The first territory costs 100 of the starting 280 gold, leaving 180 for a defense. Ashneedle provides inexpensive rapid fire, Pyre provides area damage, Obelisk intercepts durable enemies, and Stormspire trades single-target damage for crowd coverage. At level 3, a Revenant takes 23 Ashneedle hits, 10 Pyre blasts, or four Obelisk hits. Branch bonuses change these thresholds.

## Level 4

Costs are the individual branch purchase. Both choices for a tower cost the same. Selling also returns uncollected earnings. Moving retains the branch, uses 20% of total investment, and starts the established rebuild timer.

| Base tower | Branch | Base damage | Interval (s) | Range | Blast radius | Upgrade gold | Total investment | Sell gold |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Ashneedle | Frostneedle | 15 | 0.30 | 160 | 0 | 180 | 400 | 200 |
| Ashneedle | Thorn Volley | 15 per arrow | 0.30 | 160 | 0 | 180 | 400 | 200 |
| Pyre | Cinderfield | 27 | 1.10 | 154 | 66 | 320 | 760 | 380 |
| Pyre | Rupture Pyre | 54 | 1.50 | 154 | 66 | 320 | 760 | 380 |
| Obelisk | Grave Echo | 110 | 0.90 | 189 | 0 | 360 | 880 | 440 |
| Obelisk | Doomstone | 90 | 0.90 | 189 | 0 | 360 | 880 | 440 |
| Stormspire | Tempest Web | 7 | 0.30 | 173 | 0 | 300 | 760 | 380 |
| Stormspire | Thunderseal | 7 | 0.30 | 173 | 0 | 300 | 760 | 380 |

- **Frostneedle:** 25% movement slow for 2 seconds. Hits refresh duration without stacking. Blue body, icy crown, pale needles, and enemy frost rings.
- **Thorn Volley:** five arrows; the center tracks its target and all retain level-3 damage. Outer arrows travel at fixed offsets of ±0.24 and ±0.48 radians, hit the first enemy on their path, and can miss. Green thorn armor and a five-pronged launcher.
- **Cinderfield:** 3-second burning patches deal 12 damage per second. Same-tower overlapping patches refresh and never stack damage on an enemy. Different towers own independent fire. Dark cracked basin, molten orange fire, glowing scorch marks.
- **Rupture Pyre:** pushes victims 20 world units backward along their road, or 5 for Revenants. One-second immunity prevents repeated pushes. Reinforced iron brazier and expanding orange shockwaves.
- **Grave Echo:** up to five seeking fragments, each dealing 20% of the original hit (22 by default), target distinct enemies within 90 units of impact. They exclude the original target and never split again; unused fragments fade. Fractured violet crystal with five floating shards and curved trails.
- **Doomstone:** first hit deals base damage; subsequent same-target hits gain 20% per stack up to five stacks (+100%, or 180 damage). Changing targets resets this tower's curse. Dark floating monolith and brightening curse runes.
- **Tempest Web:** five primary targets; each arcs to one distinct additional enemy within 60 units for half damage (3.5). Primary targets cannot receive secondary arcs. Secondary arcs may extend beyond tower range. Branching metal crown and blue-white lightning web.
- **Thunderseal:** each tower tracks charges independently on each enemy. The fifth hit adds triple-hit bonus damage (21) and resets charges. The 0.4-second stun has 2-second immunity measured from detonation. Suspended storm rings, charge marks, and bright electrical detonations.

## Validation and saves

The selected branch persists through saving and relocation and contributes to sale/refund investment. Old level-1–3 saves remain valid. Version-1 high-level towers still migrate to level 3 with full refunds for the removed upgrades using original individually rounded prices, requiring an explicit new branch purchase. Migration remains idempotent and preserves stored earnings. Charges, curses, slows, and fire are transient combat state.

`tests/branch_runner.gd` checks branch transactions, save roundtrips, effects, immunity, fan collisions, and distinct fragment/arc targets. `tests/rendered/branch_visual_runner.gd` checks both preview buttons with mouse/touch, compact layouts, and purchasing, and produces `artifacts/level-four-branches.png`. Both run through `launch.ps1 -Check`.

`tests/unit/tower_balance_checks.gd` retains deterministic level-1–3 balance scenarios across three seeds, four approaches, basic openings, and mixed traffic at base/maximum density. These scenarios spawn for two minutes and drain for 30 seconds. `artifacts/tower-balance.csv` reports clear percentage and gold per minute for that cohort. This benchmark does not predict every placement, and the new branches have not yet received equivalent long-form balance tuning.

The Excel reference is `outputs/01a073f8-7757-7fd0-acb0-5b552511c00b/Enemy_and_Tower_Stats.xlsx`. Its Towers table includes all eight level-4 choices and effect rules. Editing the reference workbook does not modify game balance.
