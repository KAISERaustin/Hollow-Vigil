# Unified UI design discussion

Decision record started September 7, 2026. This is a proposed design being developed with the user; it does not describe implemented changes. The current implementation is mapped in `docs/UI_MENU_TREE.md`.

## Confirmed direction

- Campaign and Infinite should open matching menus, with mode-specific details appearing later. Continue, New game, My builds and Community are the working menu actions; final labels and ordering remain open.
- During play, one menu button should occupy the same position in both modes. Its exact position remains open.
- A private backup should preserve the complete game, including progress, edited rules, towers and equipment.
- Signed-in cloud backups should happen automatically, with a **Back up now** action available too. The exact upload triggers, failure/retry policy and conflict handling remain open.
- When restoring against an existing local version, ask the player which version they want to keep and let them decide. Do not automatically select a winner. Exact comparison details and recovery-copy behavior remain open.
- Continuing or restoring an unfinished Campaign battle should restart the current wave from its saved starting state.
- Reusable saves must support different contents for each mode. Standardizing navigation must retain those choices.
- Show individual content-group choices every time a reusable build is saved; do not substitute fixed presets for those choices.
- Campaign builds can cover the whole campaign or one level. Wave edits remain inside that level; individual waves are not separately reusable builds.
- Infinite examples requested by the user: a build containing tower layouts, explored tiles and stats; or stats alone for a different starting ruleset.
- Campaign examples requested by the user: wave balancing alone; or wave balancing together with which enemies spawn and starting gold. These are examples of composable contents, not a finalized preset list.

## Working distinction between saved objects

These names are proposed vocabulary, subject to the user's feedback:

| Object | Player purpose | What determines its contents |
| --- | --- | --- |
| Saved game | Continue playing an existing game | Complete progress and setup; an unfinished Campaign wave resumes from its starting checkpoint |
| Reusable build | Start another game with chosen content, or share that content | The selected mode, scope and content groups |
| Cloud backup | Recover a saved game privately on this or another device | The complete saved game, rather than the selected contents of a reusable build |

Saving a stats-only build must not be confused with creating a full backup. Likewise, public sharing and automatic private backup need clearly different names and status indicators.

## Proposed common flow to discuss

```text
Main menu
├── Campaign → Mode home
└── Infinite → Mode home

Mode home [same structure for both]
├── Continue
├── New game
├── My builds
└── Community

During play in either mode
└── Menu [same position]
    ├── Save a build
    │   ├── Scope [Campaign: whole campaign / current level]
    │   ├── Choose content groups [checkboxes every time]
    │   ├── Name and description
    │   └── Save reusable copy
    ├── Share [placement relative to Save a build remains open]
    ├── Backups → backup status / Back up now / restore
    ├── Sound
    └── Exit
```

This is a working flow, not an approved final tree. The precise content groups, save/share relationship, and navigation from a mode home remain open for discussion.

## Pending questions

Currently presented to the user:

1. Should stats be separate selectable categories, one Stats checkbox, or individual stat fields?
2. Should omitted build contents use original game defaults and a fresh starting layout, or come from another selected build?
3. Should compatible stat groups be reusable across Campaign and Infinite, while map and wave content stays mode-specific?

Later layers to resolve:

- Precisely define content groups, especially wave timing/counts versus enemy composition, combat stats, starting resources, terrain and tower/equipment loadouts.
- Define which combinations are valid and what omitted contents inherit. Include a preview before applying a build.
- Decide whether saved builds are editable drafts or immutable versions, and how locally changed Community builds are named.
- Decide where Creative/Survival selection belongs in New game and whether a selected build is applied to a fresh game or an existing editable game.
- Decide whether cloud backup also protects the private reusable-build library, beyond complete individual saved games.
- Define automatic backup timing, offline/pending status, cross-device conflicts, version history and recovery access.
- Standardize Back, Close, Cancel and Exit behavior, including treatment of unsaved edits and confirmation before replacing anything.

## Scenarios to check against the eventual design

- A player finds the same save, sharing and backup controls from Campaign and Infinite without relearning their locations.
- A player saves an Infinite stats-only build and starts a fresh world without unintentionally importing explored tiles or towers.
- A player saves the requested Campaign rule groups, and the UI explains exactly which wave/enemy/resource settings travel with the build.
- A player restores a customized game on another device and recovers its rules, progress, towers and equipment together.
- A player continues offline after the last cloud backup and can see that newer progress still needs uploading.
- A player restores while a local version already exists, compares the versions, and explicitly chooses which one to keep. Any capacity limit and recovery-copy behavior must be visible before applying the choice.
- Leaving a Campaign mid-battle and restoring it elsewhere restarts the same wave from its starting checkpoint, just as continuing locally does. The checkpoint must restore the corresponding resources and tower state consistently, without combining a reset enemy wave with later earned rewards.

The current Campaign backup only covers the original Survival completed-level count; archives and recovery files also lack a player-facing recovery browser. These known implementation gaps must be addressed if the final design promises broader recovery. This discussion has not changed save formats or game behavior.
