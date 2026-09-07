# Tan UI backgrounds

`VigilInterface.box()` selects the reusable `scripts/ui/shared/parchment_style.gd` resource for light tan fills, including the paper and darker surface palette roles. Menus, HUD chrome, dialogs, buttons, fields, popup menus, and settings cards inherit the same existing `assets/ui/welcome-parchment.png` artwork. Gold and danger surfaces use the existing yellow and red parchment variants.

The style draws an aspect-preserving cover crop inside rounded geometry and then draws the native black border. All UI enclosures use `VigilInterface.OUTLINE` (3 logical UI units), the shared 4-unit corner radius, and no shadows, as specified by [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md). Darker tan roles tint the shared texture instead of requiring separate images. The campaign screen draws the same surface across its background and redraws on resize.

Use `VigilInterface.surface()` or `box()` for future tan UI rather than a flat `ColorRect`. The welcome illustration continues to use its existing full-height paper presentation.
