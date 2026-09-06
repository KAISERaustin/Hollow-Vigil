# Boss relic equipment

Every defeated boss grants its existing gold bounty plus one guaranteed relic.
The relic rises briefly from the defeat position, enters the shared collection
automatically, and is announced in a notification. No pickup tap is required.
Escaped bosses, escorts, and offline income never grant relics. Each encounter's
source coordinate identifies its one drop; another boss of the same kind gives
a separate piece that can equip another tower.

Select any tower and tap the diamond equipment button at the upper left of its
action circle. The scrollable collection explains all four relics, including
undiscovered ones. Select a piece and Apply equipment. Pieces on other towers
identify their owner and can be transferred with the same confirmation. Empty
slot removes equipment. Cancel changes nothing.

Every tower, at every level and specialization, has one slot. Equipping and
transferring cost no gold. Replacing equipment releases the old piece; selling
returns it to the collection. Upgrades and relocation retain equipment. Towers
cannot fire while rebuilding. Relics never alter sale or relocation prices.

| Relic | Boss | Effect | Emblem |
| --- | --- | --- | --- |
| Warden’s Rootheart | Briarbound Warden | One primary shot every 6 seconds roots its target for 0.75 seconds, or 0.35 for a boss. Each enemy has a shared 3-second root immunity. | Green branching root |
| Ember Fang | The Cinder Reliquary (internal ID `cindermaw`) | Repeated attacks on the same primary target gain 8% attack speed per subsequent attack, capped at 40%. Switching targets or a 3-second attack gap clears stacks. | Amber fang |
| Tollstone | The Drowned Bell | Every fourth attack adds one primary projectile at 50% base damage, arriving 0.18 seconds later. It retains blast radius, but applies no branch or relic effects. | Teal bell |
| Eclipse Shard | The Eclipse Prior | Every fifth attack empowers its primary projectile and blast with 50% more damage and boss-defense bypass. Existing weakness bonuses remain. | Violet eclipse |

Emblems remain visible beside equipped towers and replace the empty equipment
button icon. The collection uses the same symbols and names, so identification
does not depend on color alone. Rooted enemies have visible green roots.

Attack counters advance once per tower firing cycle, not once per arrow, blast
victim, lightning target, chain, fragment, or damage-over-time tick. Tollstone
echoes only the primary shot, preventing recursive echoes and multiplied branch
procs. Eclipse bypass affects the primary shot and its blast; secondary arrows,
chains, fragments, seals, and burning ground retain their normal defenses.
Projectiles already launched retain their captured relic effect after an
equipment change; selling their tower prevents further damage as before.

Inventory and equipment ownership persist. Save validation rejects unknown
types, missing items, and an item assigned to multiple towers. Older saves
receive one relic for every recorded defeated encounter on their first load,
without another gold bounty. Already recorded escapes remain unrewarded.
Fresh resets clear the collection. Combat counters and root timers are transient,
like existing curses and stuns. Equipment changes and relocation reset counters.
Transferring equipment clears demonstrated income for the affected towers so
offline rewards must be relearned with their current equipment.

Implementation: `scripts/gameplay/progression/relics.gd`, economy transactions, combat projectile
and ability helpers, save validation, `scripts/ui/towers/relic_picker.gd`, and
`scripts/rendering/actors/relic_art.gd`. These initial effect values remain candidates
for balance tuning through playtesting.

Verification: `tests/unit/relic_checks.gd` runs with the full headless suite.
`tests/rendered/relic_runner.gd` verifies mouse/touch equipment and transfers,
saved ownership, action spacing at three zooms, and collection layouts at
360×640, 390×844, and 768×1024. Its captures use `artifacts/relic-*.png`.
