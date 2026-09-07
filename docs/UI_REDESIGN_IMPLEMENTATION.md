# Unified UI implementation

Authority: `UI_REDESIGN_DRAFT.md`, requested for implementation September 7, 2026. The draft remains the original decision record. This checklist tracks delivery and the implementation choices needed to resolve its open details.

## Shared components and ownership

- Shared page shell owns safe areas, Back/title, scrolling and pinned bottom actions.
- Shared navigation owns Game home, three-slot lists, New game, libraries, details, Save build, Backups, Settings and the held gameplay menu.
- Build content components select registered content types. Persistence owns validation and fresh-game composition; views never apply builds to an existing game.
- Campaign save owner stores each slot's identity, play style, completion, independent level rules/loadouts and a wave-start checkpoint. Infinite retains its existing save paths.
- Private backup service protects saved games and immutable library entries. Community publication remains an explicit player action.

## Resolved implementation details

- Builds are immutable snapshots. Saving again creates a separate version; importing the exact same build is idempotent. A name and contents identify a build in player screens.
- Exactly three active slots per game type. Replacement requires naming the existing game and confirming. A recovery copy is retained and browsable in Backups; restoring it also requires a matching destination.
- Automatic private backups run after local changes with a short debounce, periodically during play and after sign-in/reconnection. Failed requests retry with bounded backoff. Public publication never retries merely because a player reconnects.
- Cloud writes compare the last known version. A differing remote version is retained until the player chooses. A fresh device lists cloud games for explicit destination/restore selection; it does not consume local slots automatically.
- Wave groups use stable positions within their level/wave. Timing/count-only edits require matching group counts or an explicit choice to include enemy types/entrances; they never silently replace composition. Layout selections state required placement tiles or authored sockets and equipment ownership.
- Portable stats use level defaults, never an arbitrary wave. Campaign level source/target choices are explicit. Unselected content starts from original defaults.
- Menu pauses the held live session and Resume restores its prior pause state. Continue/Restore reconstruct a Campaign wave from its saved starting resources, towers and equipment.

## Delivery checklist

- [x] Complete Campaign slots and checkpoints; preserve active games.
- [x] Composable build contents, individual types, defaults and compatibility review.
- [x] Matching home, continue, creation and library flows.
- [x] Shared save/share form with preserved selections through account operations.
- [x] Shared HUD/menu, Settings and draft editors with Apply changes/Cancel.
- [x] Complete private backups, recovery browser and explicit version choices.
- [x] Native rendered workflow checks at 360×640, 390×844 and 540×960.
- [x] Persistence, service, gameplay and regression checks.
- [x] Updated menu tree and verification evidence.
- [ ] Commit and verified push to origin/main.

## Verification evidence, September 7, 2026

| Requirement | Verification |
| --- | --- |
| Shared navigation, wording, fixed actions and HUD placement | Native mouse menu runner: 878 checks, no failures, at all three sizes; native touch reuse: 1,319 checks, no failures |
| Continue/New game, empty/full slots and explicit replacement | Both game types, three occupied slots, canceled and confirmed replacements; unchanged sibling slots and recovery copies |
| Individual content types and original defaults | 3,894 persistence checks, including every nonempty group combination and temporary registered enemy/boss/tower types; no menu branch required for discovery or round trip |
| Campaign scopes, portable stats and dependencies | Whole/one-level choices, explicit source/target level, no Survival unlock, waves/timing/resource companion rules and placement ownership |
| Save/share, account return and failed publication | Private save offline, preserved form and checklists, explicit Retry, account change, private copy retained, Community details/pagination and private download without slot use |
| Held Menu versus Continue/Restore | Resume preserves the live battle and pause state; saved Campaign Continue reconstructs the same wave's starting economy, tower/equipment state, rules and RNG |
| Private recovery and conflict choices | 31 service checks, no failures; all six complete games, custom Campaign rules/towers/gear/checkpoint, library merge/recovery, offline retry, stale revisions and account-response guards |
| Local recovery browser | 267 native checks, no failures, across both game types and all three sizes; empty and occupied destinations, Cancel/confirm, sibling preservation, recovery of the replaced destination, active-game protection and Recover My builds |
| Deployed backend | `tests/unified_cloud_contracts.sql` passed with real roles and complete snapshot readback; every synthetic identity/build rolled back; Security Advisor returned no findings |
| Existing Campaign gameplay | 1,268 Campaign checks, 145 configuration checks, 284 full-playthrough checks, 8 reset checks, and all 20 reference level strategies passed |
| Shared gameplay and content hierarchy | Main headless suite: 52,029 checks, no failures; includes reusable attributes, inheritance, instance isolation, combat, economy, routing and persistence |
| Existing cloud compatibility | 43 service checks and 9 app restore checks passed; assertions use the new connection wording and saved-game actions |
| Layout and gameplay dialogs | Visual smoke passed, including collection, upgrade/sale, equipment, relocation, input and moving-camera simulation; UI style passed for 16 screens at three sizes; developer layouts passed 19,542 checks |
| Touch navigation and controls | 4,441 navigation checks, 480 Campaign upgrade checks, 113 equipment checks and illustrated-picker touch checks passed |
| Terrain and artwork | Campaign terrain: 660 checks; terrain palette: 38,592 pixels; boundaries: 71,040 samples; grid: 214,881 samples; all passed. Castle, portal, branch, artwork smoke, tower upgrade, construction, enemy and boss art checks also passed |

The combined `./launch.ps1 -Check` run passed through gameplay, unified menus, touch, style and terrain, then exposed an obsolete artwork fixture that requested a forest enemy from an Ashen Forge portal. The fixture now uses its registered portal roster and asserts successful spawning. Artwork smoke and every remaining Check stage were rerun successfully. The final menu, persistence, private-backup and time-control runners were also rerun after their latest changes. Logs and screenshots are regenerated in the ignored `artifacts/` directory; `tests/README.md` documents repeatable commands.

User-authorized legacy cleanup removed two cloud worlds, one legacy Campaign backup and 31 local backup files, preserving active games and the existing public build. No legacy backup migration was performed. Current cloud counts for `worlds`, `campaign_backups` and `save_revisions` are zero; the rollback contract left no synthetic users or public builds.

Visual inspection included narrow save/share forms, both rule editors, portable-stat review, Community details and local/cloud comparison. These are native desktop renders and simulated touch/second-device checks. No new installed iOS/Android build, physical second-device restore or email-delivery acceptance is claimed. The Windows environment emits its existing root-certificate-store diagnostic; the legacy app-restore harness also reports two ObjectDB instances at exit. Neither produced a script failure.
