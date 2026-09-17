# The Last Procession

The campaign is a separate tactical world with 48 authored missions in six biome chapters. A procession carries the last sanctuary's ember through a ruined kingdom, beyond the eclipsed capital to Castle Ruin and Mourning Orchard. The world map fills the screen below fixed title/Back navigation, using native chapter biome scenery, curved trails and shared black chapter dividers.

## Mission rules

- Every level begins with its own fixed gold budget and an empty set of authored tower sockets. The eight tower families, upgrades, specializations, targeting priorities and sale refunds use the existing combat rules.
- Roads, entrance lanes, enemy groups, spawn intervals and delays are predefined. Enemies follow the displayed roads even where two routes cross.
- The sanctuary begins with 3 core integrity by default. Hollows, Wraiths and Lantern Keepers reduce core integrity by 1 on arrival; Revenants and Abyss Shades reduce it by 2; Crypt Sentinels reduce it by 3. An escaped boss ends a mission with the default core integrity.
- Gold from kills is collected immediately. Each completed wave pays its displayed bonus once. Preview all waves before spending, then start each wave when ready. Building, upgrading and selling remain available during combat. Opening a tower dialog or wave preview pauses the battle.
- Win by clearing every enemy in every wave with core integrity remaining. A victory records the last beaten level and unlocks the next. Replaying a completed level does not advance progression again. There are no medals.
- Pause and playback speed are controlled by the Campaign toolbar. On phones, tap a socket to build or manage a tower; use +/− to zoom and drag to pan when zoomed in.

## Eight levels per chapter

Creative and Survival use the same save-local progression. A new save opens only level 1.
Win each level to open the next. Defeats and replays do not advance progression.
Unlocks are permanent within that save, including when replaying an earlier level.

Each of the first three chapters introduces one milestone per level in this order:

| Level within chapter | Tower | Chapter 1 | Chapter 2 | Chapter 3 |
| --- | --- | --- | --- | --- |
| 1 | Gloamwatch | Tier 1 | Tier 2 | Tier 3 |
| 2 | Pyre | Tier 1 | Tier 2 | Tier 3 |
| 3 | Obelisk | Tier 1 | Tier 2 | Tier 3 |
| 4 | Stormspire | Tier 1 | Tier 2 | Tier 3 |
| 5 | Ironspike | Tier 1 | Tier 2 | Tier 3 |
| 6 | Moonwheel | Tier 1 | Tier 2 | Tier 3 |
| 7 | Caltrop Keep | Tier 1 | Tier 2 | Tier 3 |
| 8 | Hex Lantern | Tier 1 | Tier 2 | Tier 3 |

The milestone is available when its level becomes playable. Thus Gloamwatch starts
available, beating level 1 opens Pyre for level 2, and beating chapter 1 opens
Gloamwatch tier 2. Costs still apply to building and upgrading each placed tower.
Existing tier 4 specializations become available at chapter 4; no equipment system
or equipment rewards are added. Chapters 4–6 retain their original mission rules
and receive three additional authored missions each.

Chapter 1 has gentler formations, wider spawn intervals and larger starting budgets
for learning with tier 1 towers. The three-front lesson in chapter 3 provides 1,200
starting gold to support its available upgrades. Shared entity Stats are unchanged.

| Chapter | Global level | Mission |
| --- | --- | --- |
| 1 | 1 | A Single Ember |
| 1 | 2 | Briar Bend |
| 1 | 3 | Pilgrim's Fork |
| 1 | 4 | The Old Watch |
| 1 | 5 | Needle Run |
| 1 | 6 | Moonlit Return |
| 1 | 7 | Thornway |
| 1 | 8 | Rootbound Gate |
| 2 | 9 | Cinder Causeway |
| 2 | 10 | Twin Furnaces |
| 2 | 11 | Ashen Switchback |
| 2 | 12 | The Breach |
| 2 | 13 | Iron Procession |
| 2 | 14 | Ember Circuit |
| 2 | 15 | The Furnace Road |
| 2 | 16 | The Living Furnace |
| 3 | 17 | Sunken Steps |
| 3 | 18 | Tombwater Crossing |
| 3 | 19 | The Long Descent |
| 3 | 20 | Three Tollgates |
| 3 | 21 | Flooded Gallery |
| 3 | 22 | Crescent Causeway |
| 3 | 23 | Cryptkeeper Walk |
| 3 | 24 | The Bell Below |
| 4 | 25 | Bloodmoon Avenue |
| 4 | 26 | Broken Crown |
| 4 | 27 | The Silent Court |
| 4 | 28 | Nightfall Bastion |
| 4 | 29 | Veiled Arcade |
| 4 | 30 | Procession Square |
| 4 | 31 | The Outer Vigil |
| 4 | 32 | The Last Vigil |
| 5 | 33 | The Fallen Portcullis |
| 5 | 34 | Courtyard of Echoes |
| 5 | 35 | Shattered Ramparts |
| 5 | 36 | The Empty Throne |
| 5 | 37 | Watchers Gallery |
| 5 | 38 | The Broken Stair |
| 5 | 39 | Kingsward |
| 5 | 40 | The Ruined King |
| 6 | 41 | Pale Boughs |
| 6 | 42 | The Divided Wake |
| 6 | 43 | Roots of Remembrance |
| 6 | 44 | The Last Lanterns |
| 6 | 45 | Widows Crossing |
| 6 | 46 | Pallbearer Path |
| 6 | 47 | The Quiet Grove |
| 6 | 48 | The Mourning Matriarch |

Each chapter ends with its existing boss. New missions occupy positions 5–7;
the former fifth mission moves to position 8. Save catalog revision 2 remaps old
mission identities, custom rules, portable builds and progress from five-level
chapters. Completed old chapters receive credit for their expanded chapter;
an unfinished chapter stops at its first new/unbeaten mission. Files retain their
checksum and backup handling. Imported layouts cannot bypass progression: the
playable copy refunds locked towers/upgrades while preserving the saved source.

## Progress and interruption


No active mission or preparation checkpoint is saved. Leaving a level, closing the app or restarting after defeat begins that level again with its initial gold, core integrity and empty sockets. App interruptions pause active play while the process remains alive. Old saves migrate contiguous medal completions into the completed-level count and retain an original recovery copy; old checkpoints and medal scores are discarded. Unreadable files block ordinary writes and preserve existing copies.

Open **Backups** to explicitly upload or restore Campaign progress, or use **My builds → Details → Upload build** for one private cloud build. Signing in, completing a level, restoring or reconnecting never uploads automatically. Failed attempts retry only when requested. See `CLOUD_SAVES.md` for the manual cloud contract.

## Code and verification

`scripts/campaign/catalog.gd` exposes the 48 authored layouts and wave schedules. `run.gd` owns the finite-wave state machine and mission economy; `progress.gd` owns the distinct save contract. `screen.gd`, `world_map.gd` and `board.gd` supply the native Godot interface and authored-road rendering. The common combat service provides opt-in scripted spawning, authored boss paths, and an immediate escape signal; ordinary worlds retain their existing spawn and patrol behavior.

Run `tests/campaign_runner.gd` headlessly for authored-content, economy, loss, boss route/escort, fresh-level restart, corruption, migration and progression checks. Run `tests/campaign_balance_runner.gd` headlessly to simulate legal opening strategies using actual starting gold and kill/wave rewards; its CSV records the results. Run `tests/rendered/mobile_campaign_controls_runner.gd` with a native renderer for the world map, briefing, tower actions, waves, fresh-level restart and Campaign session isolation at 360×640, 390×844 and 540×960. These desktop checks do not establish physical-phone performance or final difficulty tuning.
