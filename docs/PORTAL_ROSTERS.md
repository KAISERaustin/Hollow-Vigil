# Themed portal inhabitants

Each of the six portal types has exactly three ordinary enemies. No enemy belongs to two portal rosters. Each newly claimed non-castle tile gets a centered enemy portal with its own timer, traffic upgrades and attunements. The central core already has the receiving portal; it cannot spawn enemies onto itself. Castle ruins retain one dungeon portal per cluster.

| Biome | Starting inhabitant | Second inhabitant / attunement | Third inhabitant / attunement |
| --- | --- | --- | --- |
| Forest | Moss Hollow | Bramble Wraith / 90 gold | Rootbound Revenant / 180 gold |
| Ashen Forge | Cinder Imp | Ember Keeper / 140 gold | Slag Golem / 180 gold |
| Drowned Crypt | Drowned Thrall | Mire Wraith / 90 gold | Bell Hulk / 180 gold |
| Bloodmoon Sanctuary | Blood Acolyte | Crescent Wisp / 90 gold | Eclipse Knight / 1,100 gold |
| Castle Ruin | Abyss Shade | Crypt Sentinel / 550 gold | Sepulcher Colossus / 2,000 gold |
| Mourning Orchard | Briarling | Veil Widow / active immediately | Coffinbound / active immediately |

The four ordinary biomes use 30% second-inhabitant and 18% third-inhabitant shares after attunement; the starter receives the remaining share. Locked shares stay with the starter. Castle and Orchard portals choose equally among available inhabitants. Existing Forge health, Crypt speed and Sanctuary regeneration bonuses continue for each enemy's entire journey.

## Node and service ownership

`scripts/content/catalogs/actors.gd` supplies statistics and six `FAMILIES`. The registry builds `Enemy -> biome family -> enemy type`. `scripts/content/catalogs/world.gd` supplies each portal's roster rules, prices and weights. `PortalNode` handles selection and eligibility from supplied per-region unlock state. Combat authorizes live spawns, supplies routes and resets pooled records through `EnemyNode.create_into`. Enemy presentation assigns native renderers and existing death sounds independently from statistics. Portraits and in-world art use the same drawings.

The Forge's coal imp, anvil-headed golem and ember tender; the Crypt's waterlogged pilgrim, shell-masked ghost and bell carrier; and the Sanctuary's acolyte, crescent shrine and knight have distinct silhouettes in the existing ink-and-parchment palette. Forest inhabitants gain moss, leaves and bark. No new optional ability or timed status mechanic is added.

## Portal appearance

All six families retain their native base silhouette and compose the shared `presentation/portal` content component in the `appearance` slot. Traffic levels 1–6 add a foundation, feet, buttresses, pillars, lintel and finials. Levels 7–12 add six successive gold inlays. Each level changes the drawing at normal and reduced map zooms. The receiving core shares the stone foundation and keeps its mint heart; it has no traffic or attunement state.

Available inhabitants add ornaments at fixed mounts: Forest leaf/thorns/roots; Forge ember/lantern/anvil; Crypt reeds/shell/bell; Sanctuary crescent/ribbons/sword; Castle shroud/shield/battlements; Orchard thorns/veil/coffin. These are architectural references, not enemy models. Orchard shows its full roster immediately. Campaign portals use the current authored lane/wave roster, without inventing purchased traffic levels.

`catalogs/portal_visuals.gd` assigns reusable motifs and mounts; `nodes/portal_visual_node.gd` resolves fresh visual parts; `portal_upgrade_art.gd` draws the construction kit. Reassign or replace the component through `with_component()`, or remove it through `without_component()`. No live state is stored on these definitions. The renderer reads existing traffic/unlock fields on each draw, so loads, purchases and session switches need no visual cache or save migration. Spawn probabilities, costs, timers, routes and hit areas are unchanged.

## Existing progress and compatibility

Stable enemy IDs retain their numeric stats and developer overrides. `basic`, `fast`, `heavy`, `lantern` and `ruin_knight` receive the themed display names above. Authored campaign schedules and numeric boss escort choices retain their existing IDs and order; those encounter systems remain separate from natural portal rosters.

The save owner validates old attunements against their original portal prices, retains purchases still in that portal's roster and refunds removed purchases to spendable gold. Forest refunds its old Keeper attunement (140). Forge retains Keeper and refunds old Wraith/Revenant purchases (90/180). Crypt and Sanctuary refund old Wraith/Revenant/Keeper purchases (90/180/140). Castle refunds the old Knight attunement (1,100). Refunded IDs are removed, so repeated load/save cycles do not add another refund. Creative build imports use the same migration; restored cloud snapshots pass through the same local save boundary. Unknown or duplicate attunements remain invalid. Saved terrain, towers and independent portal traffic remain intact.

## Verification

- `tests/portal_roster_runner.gd`: all six rosters, exact probabilities across every attunement subset, foreign-enemy rejection, transactions, separate timers/health/status, pooling, claimed-tile presence, save refunds and new purchase/tuning round trips. Included in the main unit runner.
- `tests/rendered/portal_roster_checks.gd`: actual mouse/touch opening and purchases for all six portal menus at 360x640, 390x844 and 540x960.
- `tests/rendered/enemy_art_checks.gd`: eighteen distinct native portraits and four battlefield zooms, including the complete grouped lineup at `artifacts/enemy-lineup.png`.
- Existing rift-effect, Orchard, castle, campaign and persistence suites cover interactions with the rest of the game.
