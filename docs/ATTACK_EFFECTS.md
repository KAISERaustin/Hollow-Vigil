# Tower attack visuals

`scripts/rendering/attack_effects.gd` uses Stormspire's layered colored aura,
saturated strokes, and paper-white highlights as the shared visual language.

- Obelisk: violet orb, rotating arcane rings and rune ticks, weaving energy
  trails, and an expanding shock ring with radial fragments.
- Ashneedle: pointed gold dart with a bright tapered tracer, launch flash,
  and a compact spark impact that stays readable during rapid fire.
- Pyre: nested flame fronts, rolling trails and drifting embers, followed by
  a gold and coral blast ring with scattered hot sparks.
- Stormspire: its existing lightning renderer is unchanged.

All marks live inside the existing shot effect, use its age and color, and
scale with battlefield zoom. They add no particles, nodes, random gameplay
state, or damage events. Flight and impact durations are unchanged by this
visual upgrade. Pyre's ring uses the shot's existing splash radius.

Run `tests/previews/attack_effect_preview.gd` with Godot after importing the
project. It renders `artifacts/attack-effects-comparison.png`, exercises 75
animation frames, and captures flight and impact on the actual battlefield at
360 and 540 pixel viewport widths. The regular `./launch.ps1 -Tests` suite
covers shot timing, target tracking, recycling, expiration, and effect limits.
