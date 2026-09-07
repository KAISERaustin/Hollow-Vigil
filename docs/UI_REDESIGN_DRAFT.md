# Unified UI design discussion

Decision record started September 7, 2026. This is a proposed design being developed with the user; it does not describe implemented changes. The current implementation is mapped in `docs/UI_MENU_TREE.md`.

## Confirmed direction

- Campaign and Infinite should open matching menus, with mode-specific details appearing later. Continue, New game, My builds and Community are the working menu actions; final labels and ordering remain open.
- Standardize wording, ordering and placement across both game types. The same action should have the same name and behave the same way. Change wording only where the content actually differs, such as explored tiles versus Campaign waves.
- During play, one menu button should occupy the same position in both modes. Its exact position remains open.
- A private backup should preserve the complete game, including progress, edited rules, towers and equipment.
- Signed-in cloud backups should happen automatically, with a **Back up now** action available too. The exact upload triggers, failure/retry policy and conflict handling remain open.
- When restoring against an existing local version, ask the player which version they want to keep and let them decide. Do not automatically select a winner. Exact comparison details and recovery-copy behavior remain open.
- Continuing or restoring an unfinished Campaign battle should restart the current wave from its saved starting state.
- Reusable saves must support different contents for each mode. Standardizing navigation must retain those choices.
- Show individual content-group choices every time a reusable build is saved; do not substitute fixed presets for those choices.
- Offer **Select all** and separately selectable categories, including **Enemies**, **Bosses** and **Towers**. Enemies and Bosses must not be forced into one combined choice. Categories can expand to select individual types, such as one tower or enemy type, as well as the whole category.
- Omitted contents use the game's original defaults and fresh starting layout, not unrelated edits from another save.
- Compatible stat categories can be reused across Campaign and Infinite. Campaign waves and Infinite map content remain specific to their game type.
- One screen offers **Save privately** or **Share to Community**. Sharing also keeps a private copy.
- New game uses the same sequence in both game types: choose the Creative/Survival play style, choose original content or a private/Community build, review, then start.
- **Continue** opens a saved-game list in both game types, allowing the player to choose the game.
- There are exactly **three Campaign slots and three Infinite slots**, six playable game slots total. Creative and Survival use those slots within their game type; they do not each get another three slots.
- Automatically protect both complete saved games and the private **My builds** library, making both available across signed-in devices.
- Player-facing build exchange uses Community and private account backups. Do not add separate file/code Import build or Export build menus.
- Keep configuration handling entirely in the background. Players select friendly named builds, not codes, JSON, file paths, schema versions or internal identifiers. Wording and error messages must be understandable without technical knowledge.
- Campaign builds can cover the whole campaign or one level. Wave edits remain inside that level; individual waves are not separately reusable builds.
- Infinite examples requested by the user: a build containing tower layouts, explored tiles and stats; or stats alone for a different starting ruleset.
- Campaign examples requested by the user: wave balancing alone; or wave balancing together with which enemies spawn and starting gold. These are examples of composable contents, not a finalized preset list.

## Working distinction between saved objects

These names are proposed vocabulary, subject to the user's feedback:

| Object | Player purpose | What determines its contents |
| --- | --- | --- |
| Saved game | Continue playing an existing game | Complete progress and setup; an unfinished Campaign wave resumes from its starting checkpoint |
| Reusable build | Start another game with chosen content, or share that content | The selected mode, scope and content groups |
| Cloud backup | Recover saved games and the private build library on this or another device | Complete saved-game recovery plus private reusable builds; a partial build is not a substitute for a full saved game |

Saving a stats-only build must not be confused with creating a full backup. Likewise, public sharing and automatic private backup need clearly different names and status indicators.

## Shared wording proposal

Use this vocabulary throughout both flows, subject to review of the final tree:

| Label | Consistent meaning |
| --- | --- |
| Campaign / Infinite | Game type; the top-level choice |
| Play style | Creative / Survival, distinct from the game type |
| Continue | Open the three Saved games slots for the chosen Campaign/Infinite game type |
| New game | Start a separate game |
| My builds | Private reusable builds, with contents and compatibility shown |
| Community | Public builds from other players |
| Use build | Select reusable content for a game; never restore progress |
| Save build | Open the shared contents/name/save/share form |
| Save privately | Keep the selected reusable content in My builds |
| Share to Community | Publish the chosen reusable content to Community and keep a private copy |
| Contents | The same checklist structure in both game types |
| Select all | Select every applicable content group in the current checklist |
| Backups | Private protection and recovery for saved games and My builds |
| Back up now | Request an immediate private cloud backup |
| Restore backup | Recover saved progress; ask which version to keep if local progress differs |
| Back / Close / Cancel | Previous navigation step / dismiss a view / abandon a pending action; use each consistently |

Avoid alternating between Build, Configuration, Setup and Export for the same object. The proposed player UI has no code/file import or export path. Reserve words such as World, Level and Wave for the content scope; they should not create alternate names for common save/share actions.

## Proposed common tree

The following tree incorporates the answered interview questions. Placement, detailed status text and editor behavior described afterward are design proposals, not yet implemented behavior.

```text
Main menu
├── Campaign → Game home
├── Infinite → Game home
└── Shared account/settings access [proposed]

Game home [same structure; heading is Campaign or Infinite]
├── Continue → Saved games
│   ├── Slot 1 / Slot 2 / Slot 3
│   ├── Occupied slot → friendly game name, play style, progress, backup status
│   │   └── Continue game → gameplay
│   └── Empty slot → New game with this destination already selected
├── New game
│   ├── 1. Play style → Creative / Survival
│   ├── 2. Starting build
│   │   ├── Original → original rules and fresh starting layout
│   │   ├── My builds → details → Use build
│   │   └── Community → details → Use build
│   ├── 3. Review
│   │   ├── Game name, game type and play style
│   │   ├── Save slot → one of this game type's three slots
│   │   ├── Build contents and Campaign scope where applicable
│   │   └── Omitted contents → original defaults
│   └── Start game
├── My builds → private library (backed up with the account)
│   └── Build details → contents, scope, compatibility, backup status
│       ├── Use build → New game with this build already selected
│       └── Share to Community → shared save/share form
├── Community → public library
│   └── Build details → author, contents, scope, compatibility
│       ├── Use build → New game with this build already selected
│       └── Save privately → My builds
├── Backups → shared recovery screen below
└── Settings → shared settings below

During play in either mode
├── Common HUD → pause/resume and speed in matching positions
├── Content controls → tower actions; Campaign wave controls where needed
└── Menu [same position and ordering]
    ├── Resume game
    ├── Edit rules [Creative] → shared editor with relevant categories
    ├── Save build → shared save/share form below
    ├── Backups → shared recovery screen below
    ├── Settings → shared settings below
    └── Exit game → saved progress → this game's Game home

Game content [differences begin here]
├── Campaign
│   ├── World map → choose level → level preview → Begin level
│   ├── Mission → tower actions / Waves / Start wave
│   ├── Continue unfinished mission → current wave's starting checkpoint
│   └── Result → Next level / Restart level / World map
└── Infinite
    ├── World → explore tiles / build towers / manage portals
    └── Continue game → saved world

Save build [one form for both game types]
├── Scope [Campaign only: Whole campaign / This level]
├── Contents
│   ├── Select all
│   ├── Stats category → all types / individual types
│   └── Relevant map/layout/wave/resource groups
├── Name and description
├── Included contents summary + any dependencies
├── Save privately → My builds
└── Share to Community → private copy + public build
    └── Sign in / player name if needed → return to the prepared form

Backups [same screen regardless of entry point]
├── Account and backup status
├── Back up now [scope stated explicitly beside the action]
├── Saved games → choose backup → Restore backup
│   ├── Destination → one of the matching game type's three slots
│   ├── Empty destination → confirm → restore game
│   ├── Same game, differing progress → compare local/cloud versions
│   │   ├── Keep this device's version → leave local game intact
│   │   └── Use cloud version → confirm → restore game
│   ├── Different game in destination → name the game being replaced
│   │   └── Confirm replacement / Cancel
│   └── Return → Saved games
└── My builds → private library backup status and recovery

Settings [same screen regardless of entry point]
├── Account → sign in / player name / sign out
├── Sound → matching volume/mute controls
└── Creative tools [where applicable; names/placement proposed]
    └── Existing camera, health-display and testing controls
```

When a library is entered from New game, **Use build** returns to that flow without asking for the already-chosen play style again. When entered from Game home, it begins New game with the chosen build carried forward. **Save privately** in Community keeps a reusable copy in My builds; it does not start a game or consume a playable save slot. Preserve form selections and the correct return destination through account sign-in, library browsing and Back navigation.

Campaign slots and Infinite slots are separate. A new game or restored game must have an explicit destination among its game type's three slots. If all three are occupied, show the existing games and require a deliberate replacement choice and confirmation; do not create a hidden fourth slot or overwrite a different game. The exact recovery-copy policy remains a review item.

Loading one level's build into a new Campaign changes only that matching level; other levels start from original defaults. Review must state the affected level and must not imply that using its build unlocks it in Survival. A new Campaign normally opens its World map; continuing a saved unfinished mission uses the agreed wave-start checkpoint. Campaign-specific content navigation does not introduce alternate libraries or save/share screens.

Proposed treatment of portable stats: when a stat-only build has no fixed Campaign level, show **Apply to: Whole campaign / One level** in Review, with a level selector for the latter. This identifies where the selected values replace defaults; it does not import progress or unlock levels. When using stats from a whole-Campaign build in Infinite, if level defaults differ, show **Use stats from: Level [name]** before continuing. Only the chosen level's starting stat values are portable through that choice; wave-specific changes remain Campaign content. Show the included stats and unused Campaign contents in ordinary language. Never select a level or wave invisibly on the player's behalf.

**Edit rules** and **Save build** have different purposes: editing changes the current Creative game's rules; saving captures selected content for reuse. Proposed editor behavior is a draft with **Apply changes** and **Cancel**, consistently in both modes. A build picker is not an alternate route for editing an existing Survival game. The interview has not authorized a new apply-build-to-existing-game feature.

## Layout and navigation rules proposed for review

- Put **Menu** in the same top-right position during Campaign and Infinite gameplay. Match pause/speed placement as well. Exact coordinates must be checked at the supported phone sizes.
- Use full pages for Game home, Saved games, build libraries, save/share forms and Backups. Use small dialogs for confirmations and short tower actions. Keep detailed editors in one consistent presentation across modes.
- Put Back at top left, the screen title beside it, and the primary progression action in the same bottom action area. In the save/share form, show **Save privately** and **Share to Community** together in that area, in the same order.
- Match padding, typography, control sizes, content widths and scrolling. Campaign-only fields go inside the shared form rather than moving the common navigation controls.
- Back returns one navigation step and preserves form choices. Close dismisses the current view. Cancel abandons a pending edit/action. Exit game returns to Game home; returning to the main menu is a separate Back step.
- Opening the gameplay menu pauses play. Returning from that menu continues the held live session; it must not trigger a wave restart. Loading through Saved games or restoring a backup applies the agreed Campaign wave-start checkpoint rule.
- A selected build is summarized by what it contains, not only by its name. Show the game type/scope for mode-specific content and clearly mark compatible stat content usable in either mode.
- Build cards show a friendly name, optional description and plain-language contents. Configuration codes, raw data and storage details never appear in the normal player flow, including errors. Explain incompatibility as a content issue, such as a layout belonging to another level.
- An account operation must return to the screen that requested it. A failed public share leaves a private copy and the prepared form available, with a clear Retry action. Private saving remains available offline.

## Contents checklist proposal

Both modes use the same checklist, names and interaction pattern. Category checkboxes select every type inside them; expanding a category exposes individual types. Partial selections remain visible in the category summary. Selecting a group does not itself edit gameplay values.

```text
Contents
├── Select all
├── Stats
│   ├── Enemies → all / selected enemy types
│   ├── Bosses → all / selected boss types
│   ├── Towers → all / selected tower types
│   ├── Gear → all / selected gear types
│   └── Other applicable rule categories
├── Starting resources
├── Tower layout and equipment
├── Explored tiles [Infinite]
└── Waves [Campaign]
    ├── Wave timing and counts
    ├── Enemy types and entrances
    └── Wave rewards
```

This is a proposed grouping of the user's requested contents, not an approved exhaustive list. Keep **Towers** under **Stats** distinct from the placed **Tower layout and equipment**. Campaign scope is **Whole campaign** or **This level**; wave settings remain within that scope. A shared build may contain only portable stat groups.

Use brief plain-language descriptions to distinguish **Stats → Enemies** (their health, movement, rewards and other values) from **Waves → Enemy types and entrances** (which enemies appear and where). Keep level-wide stat defaults distinct from wave-specific changes when preparing portable stats; do not silently choose an arbitrary wave's effective values for an Infinite game.

The final design must define dependencies before presenting combinations as independent. For example, a tower needs a valid placement tile/socket, equipped items need compatible owners, and wave timing/count changes need an identifiable spawn group. Show any required companion contents beside the selection; do not silently include unrelated data. Resolve incompatible placement or wave content in the review screen before starting a game.

## Details to resolve while reviewing the proposed tree

All interview questions presented so far have been answered. The remaining details below are deliberately not claimed as approved behavior:

- Precisely define content groups, especially wave timing/counts versus enemy composition, combat stats, starting resources, terrain and tower/equipment loadouts.
- Define valid combinations and content dependencies. Include a preview showing selected contents and which omitted contents will use original defaults.
- Decide whether saved builds are editable drafts or immutable versions, and how locally changed Community builds are named.
- Decide how archiving/deletion and recovery copies appear while keeping exactly three active slots per game type. Slot capacity itself is settled.
- Define automatic backup timing, offline/pending status, cross-device conflicts, version history and recovery access.
- Standardize Back, Close, Cancel and Exit behavior, including treatment of unsaved edits and confirmation before replacing anything.

Automatic backup must respect the player's restore-choice requirement: if two devices have diverged, it cannot silently overwrite one version before asking. Status text must distinguish a local save, a pending private backup and a successful public share. For Campaign, describe the recoverable checkpoint as the start of the current wave, even if the backup was uploaded midway through that wave.

## Scenarios to check against the eventual design

- A player finds the same save, sharing and backup controls from Campaign and Infinite without relearning their locations.
- Corresponding screens use matching titles, action labels, ordering, navigation controls and primary-action placement at each supported screen size. Mode-specific fields occupy the same shared form structure.
- Both Saved games screens show exactly three slots, with matching empty, occupied and unavailable states. Starting or restoring one slot leaves the other five playable games untouched.
- Saving or downloading a reusable build does not occupy a playable game slot. Restoring into a full set of three slots cannot proceed without an explicit destination/replacement decision.
- A nontechnical player can save, find, use, share and restore named content without ever seeing configuration codes, raw data or implementation identifiers.
- A player can select Enemies without Bosses or Towers, select all applicable contents, and see an accurate contents summary before saving or sharing.
- A player can save one selected tower/enemy type without silently including its siblings. Loading that partial build leaves unselected types at original defaults in a new game.
- Compatible selected stats travel between game types without importing unsupported maps or wave content, and the receiving screen explains what will be applied.
- A player saves an Infinite stats-only build and starts a fresh world without unintentionally importing explored tiles or towers.
- A player saves the requested Campaign rule groups, and the UI explains exactly which wave/enemy/resource settings travel with the build.
- A player restores a customized game on another device and recovers its rules, progress, towers and equipment together.
- A player continues offline after the last cloud backup and can see that newer progress still needs uploading.
- A player restores while a local version already exists, compares the versions, and explicitly chooses which one to keep. Any capacity limit and recovery-copy behavior must be visible before applying the choice.
- Choosing the local version does not run a restore afterward. Restoring over a different named game uses an explicit replacement confirmation, not a misleading same-game version comparison.
- Using differing Campaign level stats in Infinite requires an explicit level choice; applying portable stats in Campaign clearly identifies all levels or one selected level. Neither path copies wave rules into Infinite or unlocks Campaign progress.
- Leaving a Campaign mid-battle and restoring it elsewhere restarts the same wave from its starting checkpoint, just as continuing locally does. The checkpoint must restore the corresponding resources and tower state consistently, without combining a reset enemy wave with later earned rewards.

The current Campaign backup only covers the original Survival completed-level count; archives and recovery files also lack a player-facing recovery browser. These known implementation gaps must be addressed if the final design promises broader recovery. This discussion has not changed save formats or game behavior.
