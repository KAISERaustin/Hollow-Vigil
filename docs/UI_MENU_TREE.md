# Current UI menu tree

Implemented from `UI_REDESIGN_DRAFT.md`, September 7, 2026. This describes source behavior; it does not identify the build installed on a phone. Campaign and Infinite use the same navigation owner and page shell.

```text
Hollow Vigil
├── Campaign → Saved games if occupied; otherwise Campaign home
├── Infinite → Saved games (including when all three slots are empty)
└── Settings → shared Settings

Game home [Campaign or Infinite]
├── Continue → Saved games
│   ├── Back → Hollow Vigil main menu
│   ├── Slot 1 / Slot 2 / Slot 3
│   ├── Occupied → name, Creative/Survival, progress, private backup status
│   │   └── Continue game
│   ├── Empty → New game with that destination selected
│   └── Unreadable → Recovery needed; replacement blocked
├── New game
│   ├── 1. Play style → Creative / Survival → Next
│   ├── 2. Starting build → Original / My builds / Community → Review
│   ├── 3. Review → name, explicit slot, contents, scope, dependencies, defaults
│   │   ├── Infinite stats into Campaign → Apply to: Whole campaign / One level
│   │   └── Whole-Campaign stats into Infinite → Use stats from: selected level
│   └── Start game → confirm any replacement → game
├── My builds → Build details
│   ├── Use build → New game with this build selected
│   └── Share to Community → shared Save build form
├── Community → Build details
│   ├── Use build → New game with this build selected
│   └── Save privately → My builds; no playable slot used
├── Backups → shared Backups
└── Settings → shared Settings

During play [left Menu / right pause and speed toolbar]
Campaign level Menu → world map → Saved Games
Infinite Menu / shared game menu
└── Menu
    ├── Top-left back arrow → held live session, same prior pause state
    ├── Edit rules [Creative] → isolated draft → Apply changes / Cancel
    │   ├── Infinite → registered rule categories and types
    │   └── Campaign → level → Level defaults / Wave overrides
    ├── Save build → shared form
    ├── Backups
    ├── Settings
    └── Exit game → save → matching Game home

Save build
├── Campaign scope → Whole campaign / This level
├── Contents → two checkboxes, both selected by default
│   ├── Game rules and resources → all enemies, bosses, towers, gear, rifts, starting resources, and Campaign wave settings
│   └── Layout and equipment → placed towers, upgrades, equipment, and all explored tiles [Infinite]
├── Name / Description
├── Save privately
└── Share to Community → private copy + explicit publication attempt
    ├── Account when needed → return with prepared form intact
    └── Failure → prepared form + private copy + Retry

Backups
├── Account / status
├── Back up now → all six active slots and all My builds
├── Saved games → account's backup list → Restore backup
│   ├── Explicit matching destination among three slots
│   ├── Same game → compare local/cloud progress, time, gold, towers, gear, rules
│   │   ├── Keep this device's version → no restore
│   │   └── Use cloud version → confirmation → restore
│   ├── Different game → name replacement → confirm / Cancel
│   └── Empty destination → confirm → restore
├── My builds → backup status / Recover My builds
└── Recovery copies on this device → destination → confirmation → restore

Settings [same page regardless of entry point]
├── Account → email code/link sign-in, player name, sign out → requesting page
├── Sound → mute, matching category volume controls, original defaults
└── Creative tools [held Creative game]
    ├── Unrestricted zoom and pan
    ├── Show enemy and boss health
    └── Add 1,000,000 gold

Campaign content
├── World map → level marker → preview → Begin level
├── Battle → shared tower actions / Waves / Start wave
└── Result → Next level / Restart level / World map
Infinite content
└── World → explore / towers / portals / core
```

## Navigation and ownership

Back returns one step. Close dismisses a short view. Cancel abandons a pending action; leaving a rule draft asks before discarding it. Exit game saves and returns to Game home; another Back returns to the main menu. Android Back uses the same visible navigation owner.

Full pages have a fixed Back/title header, scrollable contents and a fixed bottom action area. The full-page layer covers gameplay decorations and dialogs. The shared mobile layout component responds to safe areas and keyboard height; touch scrolling and exact-value controls retain their common behavior.

Opening Menu pauses the held live session. Resume never reloads a wave. Continue and backup restoration rebuild an unfinished Campaign battle from its wave-start checkpoint, restoring starting resources, rules, towers and equipment together. Rules edited during a wave apply to the live session and future replays; recovery of that unfinished wave uses its corresponding starting rules.

There are exactly three slots for each game type, shared between Creative and Survival. Confirmed replacements keep recoverable copies outside active slots. Restoring over a currently held game's slot requires exiting that game first. Restoring another slot does not disturb the held game; opening that restored game saves and closes the held session.

## Reusable content

Builds are immutable snapshots. Identical private saves are idempotent; a changed snapshot creates another version. A named build can contain any supported combination. Omitted fields start from original defaults. A one-level Campaign build affects that matching level only and never unlocks Survival progress.

Stats come from registered content nodes. The checklist discovers new enemy, boss and base tower types through the registry. Tower stats include the chosen type's tiers; unselected siblings are excluded. A layout carries its compatible equipment and necessary placement tiles/connecting paths or authored Campaign sockets. Timing-only or composition-only wave edits must have the original number of spawn groups; differing groups require both selections and are explained before starting.

Compatible starting stats cross game types. Infinite map/resources and Campaign waves remain within their own type. Whole-Campaign source levels and portable Campaign target levels are explicitly selected.

## Private backup policy

Local saving works offline. Signed-in changes queue a short debounce; unchanged data is skipped, periodic checks discover newer remote versions, and failures retry with bounded backoff. Every game write compares the last acknowledged cloud revision. Different versions wait for a choice. A stale choice conflicts again if another device has since written.

Private library copies merge across devices without taking playable slots. Publication happens only through Share to Community or its explicit Retry; reconnecting never publishes an old outbox. Account operations discard responses belonging to a previous account.

The user authorized deleting legacy test backups instead of migrating them. New saves use the complete slot-based backup service. Old API implementations remain for older installed clients; they are not normal navigation destinations in this UI.

## Verification

`tests/rendered/unified_menu_runner.gd` exercises native viewport mouse input at 360×640, 390×844 and 540×960. `tests/rendered/mobile_navigation_runner.gd` covers touch, keyboard-safe areas and Android Back. `tests/unified_persistence_runner.gd` covers every content-group combination, content registration, checkpoints and slot isolation. `tests/private_backups_runner.gd` exercises retry, conflict, account and cross-device service boundaries. `tests/unified_cloud_contracts.sql` verifies live SQL/RLS with rollback-only fixtures.

See `UI_REDESIGN_IMPLEMENTATION.md` for final validation results and delivery status. Native Windows rendering and simulated mobile inputs do not substitute for a physical iOS/Android build and install.
