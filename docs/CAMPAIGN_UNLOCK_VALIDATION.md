# Eight-level chapters and tower progression

Verified September 16, 2026 with Godot 4.7.2 on Windows.

The Campaign has 48 authored missions, eight in each of six chapters. Both
Creative and Survival start with only level 1 playable. The shared economy
enforces the same save-local tower milestones as the menus. Chapter 1 introduces
all eight tier 1 towers; chapters 2 and 3 introduce tier 2 and tier 3 upgrades.
Existing chapters 4–6 retain their original mission rules alongside three added
missions per chapter. Equipment remains unchanged.

## Gameplay and compatibility

- `campaign_balance_runner.gd`: 48/48 simulated victories with legal purchases,
  starting resources and earned gold. All eight chapter 1 levels finish with
  three core integrity. Reference strategies obey each tower's tier milestone.
- `campaign_unlocks_runner.gd`: 6,403 checks, zero failures. Both modes, all 48
  milestones, every tower/tier, blocked transactions, defeats, save reloads,
  replay unlocks, slot isolation, migration and imported-layout refunds.
- `campaign_runner.gd`: 3,457 checks, zero failures. Authored layouts, waves,
  Campaign simulation, refunds and sequential completion.
- `campaign_expansion_runner.gd`: 146 checks, zero failures. Old 20/30-level
  playthroughs, reusable builds, individual level builds, medals and shared-save
  identity survive catalog migration without applying it twice.
- Configuration, export, wave editor, ground save, private backup, shared Stats,
  portal effects, content schema and structure checks passed. Reference reports
  and test logs are generated under ignored `artifacts/`.

## Presentation

- `rendered/campaign_unlocks_runner.gd`: 378 checks, zero failures for both modes
  at upright 360×640, 390×844 and 540×960. Locked build cards remain disabled
  during refresh, upgrade conditions are visible, and earned upgrades work on
  earlier levels.
- `rendered/campaign_map_runner.gd`: 1,913 checks, zero failures across all six
  expanded maps at those phone sizes. Markers, labels, trails, scenery clearance,
  scrolling and saved progression remain consistent.
- `rendered/baked_map_runner.gd`: 165 checks, zero failures. Rebuilt chapter
  atlases preserve correct completed-road rendering.
- Captured phone layouts were visually inspected. These are desktop simulation
  and rendering results, not physical iOS/Android acceptance or final player
  difficulty testing.

## Cloud

Migration `20260916235811_campaign_eight_level_chapters.sql` was applied to the
Hollow Vigil project. Live validation accepts revision-2 48-level builds and
snapshots, rejects incomplete whole-Campaign builds and completion above 48,
and retains legacy numbering for old documents. Existing public builds remain
valid. The Supabase security advisor returned no findings.
