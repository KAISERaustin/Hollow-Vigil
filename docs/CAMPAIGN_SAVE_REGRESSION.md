# Campaign ground-placement save regression — September 8, 2026

Campaign checkpoint validation rebuilt only regions containing legacy tower sockets.
Live Campaign runs permit ground placement throughout nine regions. A legal tower
in a region without a legacy socket therefore caused the entire save to be rejected,
including on Briar Bend. The existing on-disk checkpoint was preserved.

`Run._prepare_regions` now supplies the same regions to gameplay and checkpoint
validation. Road, portal, footprint, tower-data and campaign-progression validation
remain in place. No save format migration is required.

The new `campaign_ground_save_runner.gd` builds legal towers across available
regions in every current level, for Creative and Survival. It writes to isolated
slots and resumes from disk before, during and between waves, checking towers,
wave and balance. It also verifies rejection of portal placements and preservation
of the prior checkpoint. The runner is included in `launch.ps1 -Tests` and `-Check`.

Validation:

- Before the fix, the initial regression fixture failed all 120 save attempts.
- After the fix, the expanded fixture passes 842 checks across all 30 levels.
- Unified persistence: 2,390 checks passed.
- Ground placement: 343 checks passed.
- Save/exit integration: 169 checks passed.
- Concurrent performance optimization checks: 9,006 passed.
- The separate saved-slot menu runner reports failures opening Infinite options,
  also with isolated test storage; that broader navigation test is not a pass.

These are desktop automated checks, not physical iOS/Android release validation.
The screenshot's live unsaved session was not available to inspect or recover.
