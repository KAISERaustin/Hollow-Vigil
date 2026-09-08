# Tower levels and specializations

All eight tower families are available in Infinite Worlds and Campaign. Each starts at level 1, upgrades through levels 2 and 3, then chooses one permanent level-4 branch. The shared construction, upgrade, targeting, equipment, sale, relocation, rules editor and save systems use the same catalog.

The tables below are generated from resolved catalog values, including recent range adjustments. `scripts/content/catalogs/towers.gd` is authoritative. Save-specific rules and equipment can change these values. Regenerate the source data with `tests/previews/tower_catalog_export.gd`.

## Levels 1–3

| Tower | Level | Damage per hit | Interval (s) | Range | Blast radius | Purchase gold |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ashneedle | 1 | 6 | 0.48 | 140 | 0 | 60 |
| Ashneedle | 2 | 10 | 0.4 | 154 | 0 | 60 |
| Ashneedle | 3 | 15 | 0.3 | 168 | 0 | 100 |
| Pyre | 1 | 15 | 1.5 | 115 | 46 | 120 |
| Pyre | 2 | 24 | 1.3 | 129 | 56 | 120 |
| Pyre | 3 | 36 | 1.1 | 143 | 66 | 200 |
| Obelisk | 1 | 40 | 1.8 | 185 | 0 | 160 |
| Obelisk | 2 | 60 | 1.35 | 201 | 0 | 140 |
| Obelisk | 3 | 90 | 0.9 | 217 | 0 | 220 |
| Stormspire | 1 | 3 | 0.4 | 160 | 0 | 140 |
| Stormspire | 2 | 5 | 0.35 | 174 | 0 | 120 |
| Stormspire | 3 | 7 | 0.3 | 188 | 0 | 200 |
| Ironspike | 1 | 22 | 1.4 | 200 | 0 | 140 |
| Ironspike | 2 | 32 | 1.25 | 215 | 0 | 120 |
| Ironspike | 3 | 44 | 1.1 | 230 | 0 | 200 |
| Moonwheel | 1 | 10 | 1.5 | 135 | 0 | 130 |
| Moonwheel | 2 | 15 | 1.35 | 145 | 0 | 120 |
| Moonwheel | 3 | 21 | 1.2 | 155 | 0 | 200 |
| Hex Lantern | 1 | 4 | 1.4 | 270 | 0 | 100 |
| Hex Lantern | 2 | 7 | 1.2 | 300 | 0 | 100 |
| Hex Lantern | 3 | 10 | 1 | 330 | 0 | 180 |
| Caltrop Keep | 1 | 24 | 2 | 125 | 0 | 120 |
| Caltrop Keep | 2 | 36 | 1.8 | 140 | 0 | 120 |
| Caltrop Keep | 3 | 52 | 1.6 | 155 | 0 | 200 |

Damage is per contact, not guaranteed DPS. Moonwheel may hit once on each travel leg and waits for its active blade to return. Ironspike loses damage on later pierced victims. Hex Lantern's marks amplify allied hits. Caltrop Keep must arm its traps and wait for contact. Attack periods advance in 0.05-second simulation ticks.

## Level 4

| Family | Branch | Damage per hit | Interval (s) | Range | Blast radius | Upgrade gold | Total investment |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ashneedle | Frostneedle | 15 | 0.3 | 168 | 0 | 180 | 400 |
| Ashneedle | Poison Arrow | 15 | 0.3 | 168 | 0 | 180 | 400 |
| Pyre | Cinderfield | 27 | 1.1 | 143 | 66 | 320 | 760 |
| Pyre | Rupture Pyre | 54 | 1.5 | 143 | 66 | 320 | 760 |
| Obelisk | Grave Echo | 110 | 0.9 | 217 | 0 | 360 | 880 |
| Obelisk | Doomstone | 90 | 0.9 | 217 | 0 | 360 | 880 |
| Stormspire | Tempest Web | 7 | 0.3 | 188 | 0 | 300 | 760 |
| Stormspire | Thunderseal | 7 | 0.3 | 188 | 0 | 300 | 760 |
| Ironspike | Siegebreaker | 60 | 1.25 | 250 | 0 | 320 | 780 |
| Ironspike | Needle Battery | 28 | 1.1 | 230 | 0 | 320 | 780 |
| Moonwheel | Reaper Wheel | 32 | 1.5 | 185 | 0 | 300 | 750 |
| Moonwheel | Orbit Crown | 12 | 0.45 | 75 | 0 | 300 | 750 |
| Hex Lantern | Oathbrand | 10 | 1 | 330 | 0 | 280 | 660 |
| Hex Lantern | Witchlight | 10 | 1 | 330 | 0 | 280 | 660 |
| Caltrop Keep | Dreadjaw | 140 | 2 | 155 | 0 | 320 | 760 |
| Caltrop Keep | Scatterworks | 32 | 2 | 155 | 0 | 320 | 760 |

- **Frostneedle:** Ice needles slow enemies by 25% for 2 seconds. Repeated hits refresh the slow; they never stack.
- **Poison Arrow:** Arrows poison their target for 3 seconds, dealing 5 damage each second. Hits from this tower refresh the poison without stacking.
- **Cinderfield:** Blasts leave burning ground for 3 seconds at 12 damage per second. Overlapping fire from this tower refreshes without stacking.
- **Rupture Pyre:** Blasts deal 54 damage every 1.5 seconds and push enemies back 20 units, reduced by enemy resistance. Enemies resist another push for 1 seconds.
- **Grave Echo:** A heavy orb bursts into 5 seeking fragments. Each deals 20% of its damage to a different enemy within 90 units. The original target is excluded; unused fragments fade.
- **Doomstone:** Consecutive hits on one enemy increase this tower's damage by 20% per curse stack, up to 100% bonus. Switching targets resets the curse.
- **Tempest Web:** Strikes up to 5 enemies. Each strike arcs to one additional, distinct enemy within 60 units for 50% damage, reaching beyond normal range.
- **Thunderseal:** After 5 hits from this tower, a seal detonates for 3 times hit damage as a bonus and a 0.4-second stun. Charges reset; 2-second stun immunity prevents continuous lockdown.
- **Siegebreaker:** Heavy bolts pierce 3 enemies at full damage. Boss hits deal 1.5 times damage before defenses. A slower reload rewards focus fire.
- **Needle Battery:** Fires 3 parallel bolts, each piercing 4 enemies. A victim takes at most one hit per volley; wider coverage trades away single-target force.
- **Reaper Wheel:** A giant serrated crescent cuts through 8 enemies on each leg. Its broad, long corridor and slower throws reward dense traffic.
- **Orbit Crown:** Three blades orbit in a short radius, sweeping all nearby enemies every 0.45 seconds. Each enemy takes one hit per sweep, never one hit per blade.
- **Oathbrand:** Concentrates on one enemy: +35% incoming tower damage for 4 seconds. Only the strongest mark applies; boss defenses remain intact.
- **Witchlight:** Marks add 20% incoming damage. A directly marked death spreads the mark to 3 nearby enemies for 3 seconds. Spread marks never spread again.
- **Dreadjaw:** Stores 3 heavy jaw traps. Each deals 140 damage to one victim, arms in 1 seconds, and expires after 12 seconds.
- **Scatterworks:** Deploys 3 weaker caltrops per cycle at separate road positions. Stores up to 9; each damages one victim and disappears.

## Reusable behavior and lifecycle

The new families attach `piercing_attack`, `returning_attack`, `orbit_attack`, `vulnerability_mark`, `tower_boss_damage` and `road_traps` content components. They can be attached to other tower definitions without modifying their parents. `TowerComponents` owns instance epochs and cleans up removed capabilities. `line_projectiles.gd` leads along the target's current road once at launch, then resolves swept collisions without homing. Returning blades retain separate hit sets for each leg; parallel volleys share a victim set. Ground gear procs occur once per launch.

Only the strongest active vulnerability applies. Each source retains its own expiry, so removing a stronger lantern restores any weaker valid mark. Witchlight spreads directly applied marks once; propagated marks cannot spread recursively. Boss defenses still resolve through the shared damage owner.

A shared spatial road index deduplicates overlapping routes and refreshes when Infinite routes or authored Campaign roads change. Trap placement queries nearby segments instead of rescanning every road for each tower. Traps occupy actual road positions inside the tower's reach, have finite capacity and lifetime, and never block movement. They prepare during Campaign planning without spawning enemies, advancing waves or earning gold. Selling, moving, changing branches or replacing components clears their owned effects. Save files and portable builds preserve tower identity, level, branch, target mode, gear and investment. Transient blades, marks and traps are not restored as an offline stockpile. Campaign resumes its existing wave checkpoint rules.

## Validation

- `tests/tower_expansion_runner.gd`: real attack cadence, moving targets, all five stages per family, all eighteen gear types, attach/remove behavior, saves and portable builds, and every authored Campaign mission.
- `tests/tower_expansion_balance_runner.gd`: three seeds and four approaches, basic openings, mixed traffic, every branch and Hex Lantern paired with the same allied defense. Initial marks can improve damage without crossing a kill threshold; upgraded support is checked against that allied income baseline.
- `tests/tower_expansion_stress_runner.gd`: forty offscreen towers across forty active rifts, every new stage, exact income accounting and bounded traps. The indexed placement pass measured 7.29 ms per simulation tick versus 45.48 ms before indexing on this Windows test host.
- `tests/test_runner.gd`: shared economy, old tower balance, movement, combat, tuning, gear, persistence and crowded-world regressions. The established solo balance thresholds remain assigned to the original four towers.
- `tests/rendered/tower_upgrade_preview_runner.gd`: every tower, tier and branch in both modes at 360, 390 and 540 UI-unit phone widths, including touch, bounds, scrolling and pinned purchase controls.
- Build selection, developer layout, equipment, framing, audio, Campaign export and unified persistence runners cover the connected menus and services.

September 7 delivery checks passed: 56,466 shared gameplay checks; 4,818 tower integration checks including all 30 authored missions; 21,333 upgrade-preview checks; 1,416 construction-card checks; 1,983 shared-menu checks; and 2,390 unified persistence checks. The rendered checks use the supported 360x640, 390x844 and 540x960 portrait sizes. The structural dependency check passes. These are Windows Godot results with injected mobile input; no physical phone build or installation is claimed.
