# The Last Procession

The campaign is a separate tactical world with 20 authored missions. A procession carries the last sanctuary's ember through a ruined kingdom, relighting sanctuaries on its way to the eclipsed capital. Open **Campaign · The Last Procession** from Saved games, or **Settings → The Last Procession → Play** from a sandbox game.

## Mission rules

- Every level begins with its own fixed gold budget and an empty set of authored tower sockets. The four tower families, upgrades, specializations, targeting priorities and sale refunds use the existing combat rules.
- Roads, entrance lanes, enemy groups, spawn intervals and delays are predefined. Enemies follow the displayed roads even where two routes cross. There is no territory purchase or continuous rift spawning.
- The sanctuary begins with 20 flame. Hollows, Wraiths and Lantern Keepers consume 1 flame on arrival; Revenants and Abyss Shades consume 2; Crypt Sentinels consume 3. An escaped boss ends the mission.
- Gold from kills is collected immediately. Each completed wave pays its displayed bonus once. Preview all waves before spending, then start each wave when ready. Building, upgrading and selling remain available during combat. Opening a tower dialog or wave preview pauses the battle.
- Win by clearing every enemy in every wave with flame remaining. Three medals require no leaks, two require at least 10 flame, and one requires survival. A victory unlocks the next level; replays retain the best medal. Medals do not grant economic bonuses.
- Pause and 2× speed operate independently of the sandbox. On phones, tap a socket to build or manage a tower; use +/− to zoom and drag to pan when zoomed in.

## The twenty sanctuaries

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

Levels 1–5 are forest, 6–10 are Ashen Fortress, 11–15 are Drowned Crypts, and 16–20 are Eclipsed Capital. Regional enemy effects match their visual theme. The first campaign Warden uses 1,800 health, a 300-point shield and a 12-second regrowth timer to introduce boss counters; the sandbox Warden is unchanged.

## Progress and interruption

Campaign medals and the current preparation checkpoint live in `user://vigil-campaign.save`, with checked temporary writes and a recovery copy. This is local campaign progress, separate from the three sandbox slots and their cloud backups. The campaign does not import sandbox gold, tuning, relics or offline income.

The checkpoint stores the level, next wave, remaining flame, gold, and tower placements/upgrades/targeting at preparation time. Launching a wave preserves that checkpoint. Returning to the world map, closing the app or retrying a defeated wave restores preparation for that wave; partial-wave earnings and purchases are rolled back together. Preparation edits save immediately. App interruptions pause active play. An unreadable campaign file blocks writes and preserves existing copies.

## Code and verification

`scripts/campaign/catalog.gd` owns the 20 layouts and wave schedules. `run.gd` owns the finite-wave state machine and mission economy; `progress.gd` owns the distinct save contract. `screen.gd`, `world_map.gd` and `board.gd` supply the native Godot interface and authored-road rendering. The common combat service provides opt-in scripted spawning, authored boss paths, and an immediate escape signal; ordinary worlds retain their existing spawn and patrol behavior.

Run `tests/campaign_runner.gd` headlessly for authored-content, economy, loss, boss route/escort, checkpoint, corruption and progression checks. Run `tests/campaign_balance_runner.gd` headlessly to simulate legal opening strategies using actual starting gold and kill/wave rewards; its CSV records the results. Run `tests/rendered/campaign_runner.gd` with a native renderer for the world map, briefing, tower actions, waves, resume and sandbox isolation at 360×640, 390×844 and 540×960. These desktop checks do not establish physical-phone performance or final difficulty tuning.
