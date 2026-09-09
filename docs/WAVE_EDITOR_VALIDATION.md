# Wave editor verification — September 9, 2026

Creative now supports adding and removing waves, direct quantity entry from enemy cards, and immediate saving. Active combat locks wave editing, including paused combat. Survival uses saved Creative configurations.

New waves require confirmation, start empty, and copy the first configured wave's reward and wave settings. Empty waves are skipped without paying completion gold. A level must retain at least one enemy. Reset wave restores its authored composition; Reset all waves restores the authored sequence. Removing a cleared wave remaps the current wave index without replaying it.

Each enemy group has an enemy/boss type, quantity, entrance portal, spawn delay, spawn spacing, and optional gold per defeat. The picker contains 18 enemies and six bosses. Repeated enemy types can have separate portals, timing, and rewards. Group rewards remain independent of global entity Stats and survive sharing, reloads, and Survival play.

Safety limits: 10,000 waves per level, 32 groups per wave, 1,000 enemies per group, and 5,000 enemies per wave. Invalid edits retain the previous saved configuration.

## Verification

- `tests/wave_editor_runner.gd`: 205 checks, zero failures. Covers all 30 levels, added and removed waves, empty-wave scheduling, active-wave locks, progress remapping, persistence, sharing, and actual enemy/boss reward credits.
- `tests/rendered/wave_editor_runner.gd`: 258 checks, zero failures. Touch interaction at 360×640, 390×844, and 540×960; new-wave confirmation, all-chapter boss selection, typed counts, portal choice, timing, rewards, reset, final-enemy protection, and Creative/Survival access.
- `tests/rendered/wave_menu_runner.gd`: 6,699 checks, zero failures. Existing summaries and balancing details remain reachable and fit portrait layouts. Screenshots visually inspected, including the corrected quantity-button width and stable save-status layout.
- `tests/campaign_configuration_runner.gd`: 205 checks, zero failures.
- `tests/campaign_export_runner.gd`: 450 checks, zero failures, including group rewards and compatibility with the concurrent global Stats changes.
- Campaign runner: 2,422 checks; expansion runner: 34; ground-save runner: 842; tuning-schema runner: 1,583. All passed.
- Source loading: 238 scripts, zero failures. Structure check passed.

The initial combined test run encountered errors and outdated assertions during concurrent Stats development. The affected runners were corrected and rerun successfully; the results above are the completed individual runs. Windows reported its existing certificate-store warning. Physical iOS/Android keyboard, safe-area and device interaction acceptance remains untested.
