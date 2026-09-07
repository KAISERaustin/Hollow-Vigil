# The Last Procession

The campaign is a separate tactical world with 30 authored missions in six biome chapters. A procession carries the last sanctuary's ember through a ruined kingdom, beyond the eclipsed capital to Castle Ruin and Mourning Orchard. The world map fills the screen below fixed title/Back navigation, using native Infinite biome scenery, curved trails and shared black chapter dividers.

## Mission rules

- Every level begins with its own fixed gold budget and an empty set of authored tower sockets. The four tower families, upgrades, specializations, targeting priorities and sale refunds use the existing combat rules.
- Roads, entrance lanes, enemy groups, spawn intervals and delays are predefined. Enemies follow the displayed roads even where two routes cross. There is no territory purchase or continuous rift spawning.
- The sanctuary begins with 3 core integrity by default. Hollows, Wraiths and Lantern Keepers reduce core integrity by 1 on arrival; Revenants and Abyss Shades reduce it by 2; Crypt Sentinels reduce it by 3. An escaped boss ends a mission with the default core integrity.
- Gold from kills is collected immediately. Each completed wave pays its displayed bonus once. Preview all waves before spending, then start each wave when ready. Building, upgrading and selling remain available during combat. Opening a tower dialog or wave preview pauses the battle.
- Win by clearing every enemy in every wave with core integrity remaining. A victory records the last beaten level and unlocks the next. Replaying a completed level does not advance progression again. There are no medals.
- Pause and 2× speed operate independently of the sandbox. On phones, tap a socket to build or manage a tower; use +/− to zoom and drag to pan when zoomed in.

## The thirty sanctuaries

| Level | Sanctuary | Placement problem |
| --- | --- | --- |
| 1 | A Single Ember | Overlapping coverage at a bend |
| 2 | Briar Bend | Reach both sides of a hairpin |
| 3 | Pilgrim's Fork | Two entrances, one shared defense |
| 4 | The Old Watch | Concentrate damage on armored enemies |
| 5 | Rootbound Gate | Break the Briarbound Warden's regenerating shield |
| 6 | Cinder Causeway | Handle the Forged health bonus |
| 7 | Twin Furnaces | Alternate between two fronts |
| 8 | Ashen Switchback | Use area attacks against packed waves |
| 9 | The Breach | Protect a short side entrance |
| 10 | The Living Furnace | Slow the Cinder Reliquary's second-phase rush |
| 11 | Sunken Steps | Account for faster Drowned enemies |
| 12 | Tombwater Crossing | Cover crossing, independently routed lanes |
| 13 | The Long Descent | Stop durable Crypt Sentinels |
| 14 | Three Tollgates | Balance three late-converging approaches |
| 15 | The Bell Below | Control the Drowned Bell and its summoned escorts |
| 16 | Bloodmoon Avenue | Overcome regeneration with concentrated fire |
| 17 | Broken Crown | Invest differently in a long and a short road |
| 18 | The Silent Court | Match specializations to three fronts |
| 19 | Nightfall Bastion | Sustain a defense through six mixed waves |
| 20 | The Last Vigil | Defeat the Eclipse Prior and relight the capital |
| 21 | The Fallen Portcullis | Establish a defense along the inner wall |
| 22 | Courtyard of Echoes | Cover both courtyard stairways |
| 23 | Shattered Ramparts | Reach armored formations twice along the ramparts |
| 24 | The Empty Throne | Reserve damage for the short eastern entrance |
| 25 | The Ruined King | Break the king's stone body while holding his guards |
| 26 | Pale Boughs | Meet the orchard's three native enemy types |
| 27 | The Divided Wake | Cover two intertwined funeral roads |
| 28 | Roots of Remembrance | Slow durable enemies around a long bend |
| 29 | The Last Lanterns | Balance three approaches to the final grove |
| 30 | The Mourning Matriarch | Focus the Matriarch while protecting the side entrance |

Levels 1–5 are Forest, 6–10 are Ashen Forge, 11–15 are Drowned Crypt, 16–20 are Bloodmoon Sanctuary, 21–25 are Castle Ruin, and 26–30 are Mourning Orchard. The first twenty levels keep their existing identities, roads, waves and rules. Their completed saves unlock level 21; legacy twenty-level builds remain readable and the new chapters use default rules for missing entries.

## Progress and interruption

Campaign stores only the number of sequential levels completed in `user://vigil-campaign.save`, with checked temporary writes and a recovery copy. It is independent of all three Infinite slots and does not import their gold, tuning, relics or offline income.

No active mission or preparation checkpoint is saved. Leaving a level, closing the app or restarting after defeat begins that level again with its initial gold, core integrity and empty sockets. App interruptions pause active play while the process remains alive. Old saves migrate contiguous medal completions into the completed-level count and retain an original recovery copy; old checkpoints and medal scores are discarded. Unreadable files block ordinary writes and preserve existing copies.

Open **Account & backups** to explicitly upload or restore Campaign progress. Signing in, completing a level, restoring or reconnecting never uploads automatically. Failed attempts retry only when requested. See `CAMPAIGN_SAVE_DESIGN.md` for the complete manual backup contract.

## Code and verification

`scripts/campaign/catalog.gd` owns the 20 layouts and wave schedules. `run.gd` owns the finite-wave state machine and mission economy; `progress.gd` owns the distinct save contract. `screen.gd`, `world_map.gd` and `board.gd` supply the native Godot interface and authored-road rendering. The common combat service provides opt-in scripted spawning, authored boss paths, and an immediate escape signal; ordinary worlds retain their existing spawn and patrol behavior.

Run `tests/campaign_runner.gd` headlessly for authored-content, economy, loss, boss route/escort, fresh-level restart, corruption, migration and progression checks. Run `tests/campaign_balance_runner.gd` headlessly to simulate legal opening strategies using actual starting gold and kill/wave rewards; its CSV records the results. Run `tests/rendered/campaign_runner.gd` with a native renderer for the world map, briefing, tower actions, waves, fresh-level restart and sandbox isolation at 360×640, 390×844 and 540×960. These desktop checks do not establish physical-phone performance or final difficulty tuning.
