# Three-level tower balance

Every tower is built at level 1 and can be upgraded twice: 1 → 2 → 3. Level 3 is the maximum, including for saved towers. Prices below are the default balance; Developer Controls scale base stats and prices for the current save.

## Gold investment

| Tower | Build, level 1 | Upgrade to level 2 | Upgrade to level 3 | Total at level 3 | Sell at level 3 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ashneedle | 60 | 60 | 100 | 220 | 110 |
| Pyre | 120 | 120 | 200 | 440 | 220 |
| Obelisk | 160 | 140 | 220 | 520 | 260 |

All values are gold. Selling also returns the tower's uncollected earnings. Upgrading never collects earnings or charges for a nonexistent fourth level. The field guide lists both upgrade prices; the upgrade dialog shows the destination level and price, or a disabled “Max level” confirmation.

The first territory leaves 180 of the starting 280 gold, so every tower remains an affordable first purchase. That budget can also buy an Ashneedle through level 2 while leaving 60 gold for a second Ashneedle. Upgrades trade gold for stronger use of an occupied socket, while building another tower adds coverage and independent targeting.

## Combat stats

| Tower | Level | Damage per hit | Attack interval (s) | Reach | Blast radius |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ashneedle | 1 | 6 | 0.48 | 132 | — |
| Ashneedle | 2 | 10 | 0.40 | 146 | — |
| Ashneedle | 3 | 15 | 0.30 | 160 | — |
| Pyre | 1 | 15 | 1.50 | 126 | 46 |
| Pyre | 2 | 24 | 1.30 | 140 | 56 |
| Pyre | 3 | 36 | 1.10 | 154 | 66 |
| Obelisk | 1 | 40 | 1.80 | 157 | — |
| Obelisk | 2 | 60 | 1.35 | 173 | — |
| Obelisk | 3 | 90 | 0.90 | 189 | — |

Reach and blast radius use world units. Combat advances every 0.05 seconds, so intervals round up to the next simulation tick (the initial Ashneedle interval effectively takes 0.50 seconds). Tiny floating-point residue does not add another tick to exact intervals.

## Roles and pricing rationale

- **Ashneedle:** the inexpensive generalist. The final tier defeats a 15-HP Hollow or 12-HP Wraith in one hit and fires more than three times per second. It still needs six hits for an 85-HP Revenant, so durable enemies can occupy its targeting time.
- **Pyre:** dense-traffic coverage. Increasing blast radius lets one attack serve several enemies. Its final tier needs three blasts per Revenant; its single-target damage rate remains below the other maximum-level towers. Its higher upgrade investment pays off when enemies cluster.
- **Obelisk:** long reach and heavy-enemy interception. Revenants take three hits at level 1, two at level 2, and one at level 3. Faster attacks at the final tier make the 520-gold total investment useful, while its single-target shots still sacrifice crowd throughput.

Enemies keep their existing health, speed, reward, and spawn proportions. A mixed maximum-traffic rift produces about 2.35 enemies per second with about 62.8 combined HP per second on average. Damage per second alone does not predict earnings: overkill, firing opportunities, target priority, range, and clustered targets all matter. Further growth uses additional defenses, territory, and rift traffic once a tower reaches level 3.

## Validation and saves

`tests/unit/tower_balance_checks.gd` runs 264 deterministic scenarios: three world/random seeds, four approach directions, every tower and level, opening Hollow traffic, mixed traffic at base/max density, and a combined level-three defense. Each scenario spawns for two minutes, then drains the cohort for 30 seconds. The generated `artifacts/tower-balance.csv` reports clear percentage and gold per minute; its income divides by the two-minute spawning window and includes later kills from that cohort. This is a repeatable balance benchmark, not a forecast for every placement or world layout.

The progression checks cover exact affordability boundaries, two successful upgrades, repeated and stale actions, the level-three cap, sale totals, hit thresholds and actual firing cadence. Rendered checks exercise the upgrade and maximum-level dialogs with mouse/touch and compact layouts.

The full unit suite includes these checks. For focused balance iteration after importing the project, run Godot headless with `--script res://tests/tower_balance_runner.gd` in an isolated test user-data environment; this also writes `artifacts/tower-balance-results.txt` and omits unrelated large-world stress tests.

Version 1 saves migrate to version 2. Existing levels 1–3 remain; higher towers become level 3 and receive a full refund for the removed upgrades using their original individually rounded prices. Stored earnings and unrelated progress stay intact. Production history is relearned for capped towers. Migration validates old data first, preserves recovery sequence ordering, and cannot refund again after the migrated save is committed.
