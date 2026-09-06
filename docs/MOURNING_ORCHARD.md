# Mourning Orchard

## Art and encounter design

The existing terrain uses muted flat fields, ivory roads, black outlines and small native silhouettes. The Orchard extends that palette with olive earth (`a5aa73`), ivory thorn trees and hanging burial urns. Its root-bound arch carries a suspended mourning veil. Native drawing keeps the tile, portal and inhabitants consistent with the other biomes at every zoom; there are no external art dependencies.

| Enemy key | Name | Health | Speed | Bounty | Knockback resistance |
| --- | --- | ---: | ---: | ---: | ---: |
| `briarling` | Briarling | 85 | 86 | 13 | 0% |
| `veil_widow` | Veil Widow | 260 | 43 | 28 | 25% |
| `coffinbound` | Coffinbound | 820 | 22 | 64 | 90% |

The narrow antlered Briarling pressures attack speed, the split-veiled Widow rewards sustained fire, and the walking coffin rewards heavy damage. Each has a native portrait, gameplay silhouette and original synthesized death cue.

## World and spawn contract

- A separate seeded random stream grows exactly one orthogonally connected patch of 6–9 tiles, within coordinates −9…9 and outside the opening two rings. Castle ruins are excluded before growth. No combat/economy RNG is consumed.
- Every Orchard tile holds a centered portal, connecting roads and four build pads. Each portal has its own spawn timer and traffic upgrades, including on previously saved Orchard tiles.
- The portal chooses the three inhabitants with equal probability; all are immediately available. Normal unlocks are rejected. Traffic uses normal costs, bounds and cadence.
- Forced spawns, ordinary rifts, dungeon portals, boss escorts and authored nonportal mission spawns cannot introduce Orchard inhabitants elsewhere. The boss escort dropdown retains its six existing numeric meanings.
- Already purchased regions keep their saved appearance. New worlds guarantee the full patch. An old save that owns the chosen entrance keeps its existing portal; no purchased terrain, towers or attunements are replaced.

## Configurations and backend

`Balance.ENEMIES` and its tuning schema drive the developer selector, editable fields, live stats, save validation and build import. The new keys use the existing schema; health edits preserve the remaining-health fraction and speed/payout/resistance apply through the shared combat systems.

Local saves, exported Creative configurations, Community builds and Survival imports retain these values. Cloud format 2 stores them in `world_rules.tuning` and stores the terrain in `regions.style`. The deployed extensible-content constraint already permits `mourning_orchard`; no new database migration is needed.

Live acceptance on 2026-09-06 used the normal QA account through the game's production HTTP service. It uploaded the world, synced a later Coffinbound HP change to 901, read both revisions, queued/published/read a build and imported it into Survival with locked rules. All 22 checks passed. Direct SQL then confirmed nine Orchard region rows and all twelve edited enemy fields in both `world_rules` and `public_builds`, including HP 901. The exact temporary QA world and public build were deleted after readback, with zero matching rows remaining.

## Verification

- `tests/orchard_runner.gd`: 1,557 assertions, including 100 seeds, exclusive spawns, traffic, save/build/cloud codecs and all 36 tower/specialization/enemy combinations.
- `tests/test_runner.gd`: 32,278 passing checks in the full gameplay regression suite, including the Orchard checks.
- `tests/rendered/enemy_art_checks.gd`: 81 checks covering nine unique portraits, transparent padding and four gameplay zooms.
- `tests/rendered/terrain_palette_checks.gd`: 576 biome/direction/zoom combinations, plus boundary, world-grid and cloud-reveal checks; all six terrain styles are covered.
- `tests/rendered/orchard_runner.gd`: 30 passing assertions plus the full developer harness; actual portal mouse/touch interactions, developer typing and save readback at three phone sizes, followed by the complete existing developer input harness.
- `tools/orchard_live_runner.gd`: opt-in authenticated backend/configuration acceptance; see `tests/README.md` for use and cleanup.

The rendered app teardown reports two existing audio object leaks, also observed by the separate cloud restore runner. There were no script/runtime errors or failed interaction assertions. Physical iPhone/TestFlight validation is separate from these desktop-rendered phone-size checks.

Generated visual evidence is in `artifacts/orchard-world-*.png`, `artifacts/orchard-portal-*.png`, `artifacts/orchard-developer-*.png` and `artifacts/enemy-lineup.png`. Portrait exports are committed in `assets/enemies/`.
