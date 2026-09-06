# Menu UI audit — September 5, 2026

## Changes

- Removed visible scroll bars from menu sheets, tower details, and branch descriptions. Wheel, touch, focus-following, and keyboard scrolling remain available.
- Reduced repeated vertical margins so all four Build choices and the purchase action fit at 360×640.
- Sized Settings to its content and removed the decorative introduction so its bottom action fits on the smallest tested viewport.
- Removed empty scrolling space from Expansion and added an explanation to the previously empty Core panel.
- Removed the reserved scrollbar gutter so menu contents use the available width.

## Validation

- Native Windows inspection: HUD, Settings, developer categories and dropdown, wheel scrolling to lower developer actions without visible rails, tower action cluster, information, targeting, move quote, and sell confirmation. Transaction checks used a disposable game instance.
- UI_STYLE: zero failures across 15 screens at 360×640, 390×844, and 540×960. Includes Build, Expansion, Rift, Core, Settings, Developer Controls, reset confirmation, tower details/actions, relocation destination prompt, and welcome-back earnings.
- MENU_LAYOUT: zero failures; every developer category, type, and slider is reachable at all three viewport sizes. Build choices fit without scrolling, Settings fits, and empty Expansion space is absent. Runs with `./launch.ps1 -StyleTests` and `-Check`.
- Branch visual checks: no failures across all tower branches, including simulated mouse/touch selection and purchase.
- `git diff --check`: passed.

## Remaining baseline failures

The full VISUAL_SMOKE suite reports 477 failures both with these changes and in an unchanged checkout at `9d4ba5d`. The complete ERROR message lists match. These include camera movement and zoom-dependent tower-control assertions. This audit does not claim that the full gameplay suite passes; concurrent camera and world work was excluded from this menu fix.

Native desktop tests and simulated touch do not establish physical mobile-device behavior. The existing Windows root-certificate-store warning appears in both runs.
