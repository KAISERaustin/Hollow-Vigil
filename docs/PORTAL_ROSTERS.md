# Campaign portals and enemy families

Each chapter has a native portal identity and three ordinary enemy types. Authored waves select enemy types, counts and entrance lanes. Portal effects follow the entrance biome for the entire route.

## Portal appearance

Campaign uses the same six portal kinds at every entrance in each biome's five-level chapter:

| Campaign levels | Biome | Portal kind |
| --- | --- | --- |
| 1–5 | Forest | Forest Rift |
| 6–10 | Ashen Forge | Forged Rift |
| 11–15 | Drowned Crypt | Drowned Rift |
| 16–20 | Bloodmoon Sanctuary | Bloodmoon Rift |
| 21–25 | Castle Ruin | Castle Ruin Portal |
| 26–30 | Mourning Orchard | Mourning Orchard Portal |

Edit rules → Portals discovers all six registered Portal nodes, including their native portraits. Forest, Castle Ruin and Mourning Orchard have no additional tunable portal effect; their entries display their identity without a strength input. Forge health, Crypt speed and Bloodmoon regeneration retain their existing values and saved tuning keys. Viewing a portal does not alter rules or saved games.

All six families retain their native silhouettes and compose the shared `presentation/portal` appearance component. Structural tiers and inhabitant ornaments are reusable artwork parameters; wave definitions own gameplay.

Portal ornamentation reflects each chapter's enemy family and keeps identity readable beside the authored roads.

`catalogs/portal_visuals.gd` assigns reusable motifs and mounts; `nodes/portal_visual_node.gd` resolves fresh visual parts; `portal_upgrade_art.gd` draws the construction kit. Reassign or replace the component through `with_component()`, or remove it through `without_component()`. No live state is stored on these definitions. The renderer composes each authored entrance's structural tier and inhabitant ornaments without mutating definitions.

Stable enemy IDs retain their numeric stats and developer overrides. Campaign schedules and boss escort choices select the exact enemies and routes for each encounter.

## Verification

`./launch.ps1 -Check` validates all thirty level definitions, shared content loading, terrain rendering and Campaign controls at three portrait phone sizes.
