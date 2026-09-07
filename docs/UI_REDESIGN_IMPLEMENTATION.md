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

- [ ] Complete Campaign slots and checkpoints; preserve existing saves.
- [ ] Composable build contents, individual types, defaults and compatibility review.
- [ ] Matching home, continue, creation and library flows.
- [ ] Shared save/share form with preserved selections through account operations.
- [ ] Shared HUD/menu, Settings and draft editors with Apply changes/Cancel.
- [ ] Complete private backups, recovery browser and explicit version choices.
- [ ] Native rendered workflow checks at 360×640, 390×844 and 540×960.
- [ ] Persistence, service, gameplay and regression checks.
- [ ] Updated menu tree and verification evidence.
- [ ] Commit and verified push to origin/main.
