# Ground placement validation — September 8, 2026

Campaign and Infinite now share the Build palette and ground drag interaction.
Drag upward from a tower card; swipe horizontally to browse. Release on clear
ground to build once. Roads, portals, overlapping towers, and out-of-bounds or
unowned ground reject the drop. Invalid releases retain the red preview for a
new drag. Cancel, Back, and application interruption discard the preview.

Existing tower locations remain readable. New locations persist through the
shared world location codec, so combat, selection, effects, upgrades, equipment,
and relocation resolve the same position. No purchase occurs before a valid drop.

Verified on Windows with Godot 4.7.2:

- Full unit suite: 56,466 checks, zero failures.
- Ground placement: 343 checks, zero failures, including all 20 campaign levels,
  portal/road exclusion, overlap, checkpoint/export round trips, an actual
  Infinite save/reload, and relocation.
- Rendered ground-build touch suite: 90 checks, zero failures across both modes
  at 360×640, 390×844, and 540×960. Covers catalog scrolling, drag acquisition,
  invalid retry, offscreen release, second-finger ownership, cancellation,
  interruption, exact spending, and selecting the built tower.
- Campaign suite: 2,415 checks, zero failures.
- Tower-level indicator suite: 112 checks, zero failures.
- Project import and structure checks passed. Palette and invalid-preview
  screenshots were visually inspected at portrait phone sizes.

The broader rendered visual smoke run is **not passing**: it repeatedly reports
tower-action sizing and anchoring assertions during pan/zoom in
`tests/rendered/tower_panel_checks.gd:257–258`. The run was stopped after those
repeated failures; this report does not claim a clean full rendered smoke suite.

Touch results are simulated desktop input. Physical iOS and Android validation
of dragging, safe areas, cancellation, and application interruption is pending.
The Windows certificate-store warning is environmental; Android build tools
were unavailable during import, and no native mobile export was performed.
