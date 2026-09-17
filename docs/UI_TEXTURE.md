# Moonlit UI surfaces

`VigilInterface.box()` uses the reusable `scripts/ui/shared/surface_style.gd`
resource for opaque UI fills. Its deterministic neutral grain varies by about
1.5% around the shared semantic color. Menus, HUD chrome, dialogs, buttons,
fields and popup menus inherit this material without tinting their text or art.

The style clips grain to rounded geometry and draws a native solid black rim.
Buttons use `UI.button_surface()` with `BUTTON_OUTLINE = 1`; panels, fields,
cards, badges and dividers use `OUTLINE = 1`. Both use 4-unit corners, or 0 for
edge-to-edge chrome, and no shadows. Hover, press and selection never thicken
the border. See [UI_THEME.md](UI_THEME.md) for the fixed iron, steel, violet,
bronze and emphasized action colors.

Use the shared surface helpers when composing UI. The historical parchment
textures remain artwork assets, not the runtime menu background. The title
screen keeps its full-height Pickard illustration; world scenery, portraits
and currency retain their independent artwork colors and contours.
