# Current UI menu tree

Source snapshot: September 7, 2026. This describes the current checkout's menu labels, button connections and save behavior. It is a reference to the implemented UI, not a proposed redesign or confirmation of the version installed on a phone. Repeated screens are expanded once below and referenced by name elsewhere. Screens generated from content lists are represented by their category/type selector rather than repeating every item.

`[Creative]` means the option is available only in that mode; `[Survival]` means Survival only. `→` describes the destination or result. Some rows display a descriptive label beside a short button such as **Open**, **Use**, or **Upload**; this reference keeps the descriptive label so the action can be identified.

## Start here

```text
Hollow Vigil — main menu
├── Campaign → Campaign setup
│   ├── 1. Campaign build
│   │   ├── Current title/description (original: The Last Procession)
│   │   ├── My builds → Choose campaign build → On this device
│   │   │   └── Use this build → return to Campaign setup with it selected
│   │   ├── Community → Choose campaign build → Community
│   │   │   ├── Use this build → select this whole campaign
│   │   │   └── Save on this device → private library copy, without selecting it
│   │   └── Use the original campaign [when a custom campaign is selected]
│   ├── 2. Choose your mode
│   │   ├── Creative → edit rules; all 20 levels available
│   │   └── Survival → locked rules; unlock levels in order
│   ├── Edit levels & waves [Creative] → Campaign balancing (see below)
│   ├── Save or share campaign [Creative] → WHOLE-CAMPAIGN share form
│   │   ├── Include: Campaign + loadouts / Campaign rules only
│   │   ├── Title + optional description
│   │   ├── Save on this device → Campaign setup → My builds
│   │   └── Upload to Community → local copy + public upload attempt
│   ├── Open Creative campaign / Open Survival campaign → World map
│   │   ├── Map heading: The Last Procession
│   │   ├── Tap an available level marker → Level briefing
│   │   │   ├── Board preview, story, waves, starting gold and flame
│   │   │   ├── Preview waves → Waves (see below)
│   │   │   ├── My builds [Creative] → THIS-LEVEL tower setups
│   │   │   │   ├── On this device / Community
│   │   │   │   ├── Use this build → replace pending setup; return to briefing
│   │   │   │   ├── Save on this device [Community] → local copy only
│   │   │   │   └── Create configuration → Level configuration editor
│   │   │   ├── Stats [Creative] → THIS-LEVEL rule configurations
│   │   │   │   ├── On this device / Community
│   │   │   │   ├── Use these stats → pending setup without towers
│   │   │   │   ├── Save on this device [Community] → local copy only
│   │   │   │   └── Create configuration → Level configuration editor
│   │   │   ├── Use my level defaults [after selecting a level configuration]
│   │   │   └── Begin mission → fresh mission using the selected setup
│   │   ├── Play level N → mission directly, bypassing the briefing
│   │   ├── Campaign balancing [Creative] → choose one of 20 levels
│   │   ├── Reset campaign progress [Survival]
│   │   │   └── Confirmation → Reset progress / Cancel
│   │   ├── Account & backups → shared account/backup screen
│   │   └── Back arrow → Campaign setup
│   ├── Mission / battle
│   │   ├── Back arrow → World map
│   │   ├── Pause / resume; 1× / 2×
│   │   ├── Tap an empty socket → Build a tower → select tower to buy
│   │   ├── Tap a placed tower → shared tower action menus (see below)
│   │   ├── Waves → wave previews/details and Creative editing
│   │   ├── Share [Creative] → WHOLE-CAMPAIGN share form above
│   │   ├── Start wave N → combat → next planning phase or result
│   │   └── Result: Sanctuary restored / The flame went out
│   │       ├── Next level [victory, except level 20] → next mission directly
│   │       ├── Restart level → fresh mission
│   │       └── World map
│   ├── Account & backups → shared account/backup screen
│   ├── Retry public uploads [if queued uploads exist]
│   └── Back arrow → leave Campaign, reveal main menu underneath
│
└── Infinite → Saved games
    ├── Back arrow → main menu
    ├── Slot 1 / Slot 2 / Slot 3
    │   ├── Existing game → Continue game → Infinite world
    │   ├── Existing game → Make room for a new game → Archive confirmation
    │   │   └── Archive and free slot / Cancel
    │   ├── Unreadable game → Recovery needed; Continue disabled
    │   └── Empty slot → New game
    │       ├── 1. Starting world
    │       │   ├── My builds → locally saved Infinite worlds
    │       │   │   ├── Use → return to New game with world selected
    │       │   │   └── Browse community builds → public world browser
    │       │   ├── Community → public world browser
    │       │   │   └── Use this build → return with world selected
    │       │   ├── Stats → Choose stats (see below)
    │       │   │   └── Use these stats → fresh world with those rules
    │       │   └── Use a fresh world instead [when a configuration is selected]
    │       ├── 2. Choose your mode
    │       │   ├── Creative → editable rules + Starting gold input
    │       │   └── Survival → selected rules locked
    │       ├── Start Creative game / Start Survival game → create in empty slot
    │       └── Back arrow → Saved games
    ├── Browse community builds → public world browser
    │   ├── Refresh; Previous page / Next page; Retry on load failure
    │   └── Use this build → Choose a game slot
    │       ├── Use slot N [empty slots only] → New game with build selected
    │       └── All slots full → Saved games → archive one first
    ├── Account & backups → shared account/backup screen
    └── Retry public uploads [if queued uploads exist]
```

## Campaign editing, sharing and code export

The **Campaign balancing** screen is reached from setup's **Edit levels & waves** or the map's **Campaign balancing**. The same level editor also opens from **Waves → Edit wave N** and **Create configuration** in a level picker.

```text
Campaign balancing [Creative]
└── Choose a level (01–20) → Level configuration
    ├── Scope selector
    │   ├── Level defaults
    │   │   ├── Starting gold
    │   │   ├── Sanctuary flame
    │   │   ├── Gold per cleared wave
    │   │   └── Stat categories → select type/tier → edit values
    │   └── Wave N overrides
    │       ├── Wave completion gold
    │       ├── Wave spawn groups
    │       │   ├── Enemy/boss type, count, entrance lane, delay, interval
    │       │   ├── Remove group [where allowed]
    │       │   └── Add spawn group [up to 32]
    │       └── Stat categories → select type/tier → edit values
    ├── All stat categories → editor category list
    ├── Save level configuration → keep draft edits for this level
    ├── Export saved level data → Level N balancing export
    │   ├── Read-only code: saved rules, defaults, effective stats and wave reports
    │   ├── Copy export code → clipboard
    │   └── Back to level configuration
    ├── Restore level defaults → reset draft; Save is still required
    ├── Pause / resume battle [when editing this active mission]
    ├── Save or share configuration → SINGLE-LEVEL share form
    │   ├── Include: Towers + stats / Stats only
    │   ├── Title + optional description
    │   ├── Save on this device → this level's My builds / Stats library
    │   └── Upload to Community → local copy + public upload attempt
    └── Choose saved or community stats → this level's Stats picker
        └── Use these stats → Level briefing for a new mission with those rules

Waves (from Level briefing or battle)
├── Wave N summary and enemy composition
├── Wave N balancing details → spawn stats + changes from previous wave
│   └── Back to all waves
├── Edit wave N [Creative] → Level configuration with that wave selected
└── Close → underlying briefing / battle
```

**Save before sharing or exporting from the level editor.** Those actions read the saved configuration, not uncommitted fields. The visible single-level **Save or share configuration** route creates a fresh run from saved rules; its **Towers + stats** option does **not** capture the towers currently placed in battle. The underlying code supports a current-run level export, but the current battle **Share** button calls the whole-campaign route instead.

Whole-campaign **Campaign + loadouts** includes all 20 levels' resolved rules, wave compositions/timing/rewards, any loadouts already carried by the selected campaign or selected level setups, and the currently held mission's towers/equipment/gold when a run exists. It does not automatically collect the tower layout from every mission previously played. **Campaign rules only** omits loadouts. Neither option transfers completed-level progress or an in-progress battle.

## Infinite world menus and stat configurations

```text
Infinite world
├── HUD → Settings; Pause/resume; 1×/2×; Collect all
├── Tap tower / earnings → collect that tower's earnings
│   └── Placed tower → shared tower action menus
├── Tap empty socket → Build
│   ├── Select a tower type
│   └── Build [tower] → purchase (first property must already be owned)
├── Tap neighboring + territory → Expand / Claim Castle Ruin
│   └── Claim territory → purchase
├── Tap owned portal → its rift menu
│   ├── Enemy roster: Active / Attunement required
│   ├── Increased spawn rate → Increase (or MAX)
│   └── Enemy attunements → Attune (or Attuned)
├── Tap core → Core information
├── Welcome back [when offline gold was earned] → Close
└── Settings
    ├── Player account display
    ├── Account & cloud backups → shared account/backup screen
    ├── Current game → Lifetime gold / Escaped (display only)
    ├── Creative rules → Edit → Developer Controls [Creative]
    │   ├── Session / Bosses / Rifts / Enemies / Towers / Gear
    │   │   ├── Illustrated type selector; tower tier/branch selector where relevant
    │   │   ├── Edit numeric values → live changes, auto-saved
    │   │   ├── Reset selected type / tier
    │   │   └── Reset all balance values
    │   ├── Add 1,000,000 gold
    │   ├── Unrestricted zoom and pan
    │   ├── Show enemy and boss health
    │   └── Back → categories → Settings
    ├── Custom gameplay stats → Open → Choose stats
    ├── Sound
    │   ├── Mute all sound
    │   ├── Master / Menu / Towers / Enemies / Bosses / Music volume
    │   ├── Preview sound [Music responds live instead]
    │   └── Restore sound defaults; Back → Settings
    ├── Upload build → Save or share configuration [both modes]
    │   ├── Include: Towers + stats / Stats only
    │   ├── Title + optional description
    │   ├── Save on this device → My builds (world) / Stats (rules)
    │   └── Upload to Community → local copy + public upload attempt
    ├── Reset progress → Reset all progress?
    │   └── Reset and start over / Cancel
    └── Saved Games → Exit → Saved games

Choose stats (Infinite)
├── On this device / Community
├── Create configuration → Edit stat configuration
├── Copy current game's stats [if an Infinite slot is active] → editor draft
├── Configuration → Use these stats
│   ├── From New game → select rules and return to New game
│   └── From Settings → open those rules in the editor
├── Configuration → Save on this device [Community] → library copy only
└── Edit stat configuration
    ├── Name + optional description
    ├── Session / Bosses / Rifts / Enemies / Towers / Gear
    │   └── Select type/tier → numeric fields and reset actions
    ├── All stat categories → category list
    ├── Save configuration → private library; return to Choose stats
    ├── Upload stats to Community → local copy + public upload attempt
    └── Back → Choose stats (unsaved draft edits are not committed)
```

The dedicated stat editor edits a reusable draft; saving it does not apply it to the currently running Infinite world. To use it for play, select it under **New game → Stats**. The separate **Creative rules** editor changes the current world immediately.

## Shared tower action menus

```text
Select a placed tower (Campaign or Infinite)
├── Info → stats, equipped item and level-4 specializations → Close
├── Upgrade
│   ├── Levels 1–2 → show quote → tap again to purchase
│   └── Level 3 → choose left/right specialization → checkmark to purchase
├── Move → cost/rebuild details → Choose destination
│   └── Tap valid empty owned socket to pay/place, or cancel
├── Targeting → First / Last / Most HP → Apply targeting / Cancel
├── Equipment
│   ├── Currently equipped → remove × → Remove equipment / Cancel
│   ├── Inventory → select available item → details → Equip / Back
│   └── Close
└── Sell → refund quote → Sell / Cancel
```

Availability depends on the current tower/run state and affordability. During Campaign, these actions follow the active mission's sockets and rules.

## Shared account and backup screen

Entry points: **Campaign setup → Account & backups**, **Campaign map → Account & backups**, **Infinite → Saved games → Account & backups**, **Infinite world → Settings → Account & cloud backups**, and certain upload result screens.

```text
Account & cloud backups
├── Signed out
│   ├── Retry sign-in [when a saved session exists]
│   ├── Email address → Email me a sign-in code
│   └── Email code or sign-in link → Sign in
└── Signed in
    ├── Player name → Save name
    ├── Campaign
    │   ├── Completed-level count and backup status
    │   ├── Upload campaign backup / Retry campaign upload
    │   ├── Replace campaign backup… [conflict] → confirm / Cancel
    │   ├── Restore campaign… → Restore campaign / Cancel
    │   └── Refresh campaign backup
    ├── Infinite worlds
    │   ├── Upload slot 1 / 2 / 3 backup
    │   ├── Replace slot N cloud backup… [conflict]
    │   │   └── Use this device's progress / Cancel
    │   └── Include sound preferences in the next Infinite upload
    ├── Restore an Infinite backup
    │   ├── Destination: Restore into slot 1 / 2 / 3
    │   ├── Refresh cloud saves
    │   └── Select cloud world → Restore cloud progress / Cancel
    └── Sign out
```

Backups are private account recovery, separate from Community sharing. Infinite restore replaces the chosen slot and preserves a recovery file; it does not merge progress. Campaign backup currently uses the **original Survival campaign's completed-level count** (`app.campaign_progress`), even when opened from a custom/Creative campaign. It does not back up custom campaigns, authored rules, tower loadouts, or unfinished missions. Custom campaign content travels through **Save or share campaign** instead.

## What each kind of build means

| What is being moved | Contents | Where to choose it | Result |
| --- | --- | --- | --- |
| Whole campaign | All 20 levels' rules and wave schedules; optional loadouts | Campaign setup → My builds / Community | Choose Creative or Survival; progress is separate for the mode/build |
| Campaign level build | One matching level's rules plus a loadout | Creative Campaign → level marker → My builds | Starts that mission from its setup; see the current sharing limitation above |
| Campaign level stats | One matching level's rules, including wave overrides; no loadout | Creative Campaign → level marker → Stats | Fresh mission without placed towers |
| Infinite world build | World/territories, tower layout and upgrades, equipment, resources and tuned rules | Infinite → New game → My builds / Community | Separate game in an empty slot; not a cloud restore |
| Infinite stat configuration | Reusable gameplay values, including starting-resource rules; no towers/world | Infinite → New game → Stats | Fresh world with those values |
| Saved level data export | Inspectable code/report of one level's saved configuration and effective waves | Creative Campaign → Level configuration → Export saved level data | Copy export code; no visible paste/import counterpart |
| Cloud backup | Private saved progress: Infinite slot, or original Survival Campaign completed count | Account & cloud backups | Restore progress rather than publish a reusable build |

## Short walkthroughs

- **Download and play someone else's whole campaign:** Campaign → Community → Use this build → Survival → Open Survival campaign → level marker → Begin mission (or map's Play level N).
- **Keep a whole campaign for later:** Campaign → Community → Save on this device. Later: Campaign → My builds → Use this build.
- **Share Campaign rules plus the current tower layout:** Campaign → Creative → open a mission → place towers → Share → Campaign + loadouts → title → Upload to Community.
- **Share Campaign rules without towers:** Campaign → Creative → Save or share campaign → Campaign rules only → title → Upload to Community.
- **Share only one level's saved rules:** Campaign → Creative → Edit levels & waves → choose level → edit → Save level configuration → Save or share configuration → Stats only → title → Upload to Community.
- **Load a single-level configuration:** Campaign → Creative → Open Creative campaign → tap the matching level marker → My builds or Stats → Community → Use this build / Use these stats → Begin mission.
- **Copy the visible level export code:** Campaign → Creative → Edit levels & waves → choose level → Save level configuration → Export saved level data → Copy export code.
- **Share an Infinite tower layout:** Infinite → Continue game → Settings → Upload build → Towers + stats → title → Upload to Community.
- **Share only an Infinite world's stats:** Same path, choosing Stats only. The result is found under New game → Stats → Community.
- **Start from a public Infinite layout:** Infinite → New game in an empty slot → Community → Use this build → choose mode → Start game.

## Current UI gaps and naming collisions

1. **My builds has three meanings:** whole Campaign, single Campaign level, or Infinite world, depending on where it appears. These are filtered libraries, not one interchangeable list. Campaign level Stats also differ from Infinite Stats and are filtered to the matching level.
2. **Campaign Share means the whole campaign.** Its screen is still titled **Save or share configuration**. Single-level sharing is nested inside the level configuration editor.
3. **Save on this device and Upload to Community are different actions.** Public upload also first saves a local copy. A local-save success does not establish public-upload success. Public uploads require sign-in and a player name; failed attempts need an explicit retry.
4. **Export is not a universal visible menu.** The general share form exposes local save and Community upload, without a Copy/Paste code control. `stat_configurations.gd` contains `show_import()` and `show_code()`, but no current UI button calls them. Infinite build decoding exists without a visible paste/import screen. The reachable clipboard export is the Campaign level balancing report; it has no current UI import path.
5. **The single-level Towers + stats label overstates the reachable route.** The editor's share action uses a fresh run, so it does not capture the current battle layout. Some UI tests call the current-run helper directly, which does not prove that a player can reach it through a button.
6. **Whole-campaign loadouts are not a history of all levels played.** The share path uses existing selected loadouts plus the currently held run. Earlier played layouts are not automatically gathered.
7. **Some help text is stale.** Infinite My builds still says “Save to My builds,” but the current button says **Save on this device**. It mentions Creative sharing, while **Upload build** is currently visible in Infinite Survival too. The world-map heading remains **The Last Procession** even for a differently titled custom campaign.
8. **Reset, archive and restore do different things.** Reset restarts progress; archive frees an Infinite slot while retaining files (no visible archive browser); restore replaces saved progress from a private account backup. None publishes a build.

## Source and verification pointers

- `scripts/ui/welcome_menu.gd`: top-level Campaign/Infinite choices.
- `scripts/ui/save_slots_panel.gd`: `show_slots`, `show_creation`, `show_configurations`, `show_export`, `save_build`; library and share destinations.
- `scripts/ui/configuration_picker.gd`: source tabs, family/level filtering, Use versus Save on this device.
- `scripts/ui/public_builds_panel.gd`: Infinite public browser and empty-slot selection.
- `scripts/campaign/screen.gd`: `show_setup`, `show_playthrough_picker`, `show_playthrough_share`, `show_map`, `show_briefing`, `show_battle`, `show_level_balance`, `show_campaign_share`, `show_level_export`.
- `scripts/campaign/balance_panel.gd`: draft scope, explicit save, export signal.
- `scripts/ui/panels.gd`, `scripts/ui/developer/stat_configurations.gd`, `scripts/ui/developer/developer_controls.gd`: Infinite Settings, draft versus live editors, disconnected code screens.
- `scripts/ui/towers/`, `scripts/audio/audio_settings.gd`: shared tower controls and Sound.
- `scripts/cloud/cloud_panel.gd`, `scripts/app/main.gd`: account screens and original Campaign backup binding.
- `scripts/persistence/save_slots.gd`, `scripts/persistence/campaign_build.gd`, `scripts/persistence/campaign_playthrough.gd`, `scripts/campaign/session.gd`: payload contents and per-build progress identity.
- Existing UI checks: `tests/rendered/campaign_setup_runner.gd` exercises whole Campaign save/select/replay; `tests/rendered/shared_configuration_runner.gd` exercises shared stat selection and save/upload forms using a Community test double. Direct helper calls in a test were not treated as player-visible navigation.

Verification for this reference: the current Campaign setup UI runner passed **58 checks**, and the shared configuration UI runner passed **26 checks**, with **0 failures** and no engine/script errors in either log. These checks exercised 360×640, 390×844 and 540×960 layouts. The expandable companion tree was checked for working disclosure controls in a browser. Community upload behavior was checked with fixtures; no real public build was published as part of this UI audit.
