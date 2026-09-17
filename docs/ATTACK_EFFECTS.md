# Tower attack visuals

`scripts/rendering/effects/attack_effects.gd` uses Stormspire's layered colored aura,
saturated strokes, and paper-white highlights as the shared visual language.

- Obelisk: violet orb, rotating arcane rings and rune ticks, weaving energy
  trails, and an expanding shock ring with radial fragments.
- Gloamwatch: a separate wooden arrow with an iron or elemental tip, launched
  from the black front gallery at (0, -40). No glowing launch ring or tracer;
  the hidden watchman and arrows are never baked into the tower images.

- Pyre: nested flame fronts, rolling trails and drifting embers, followed by
  a gold and coral blast ring with scattered hot sparks.
- Stormspire: its existing lightning renderer is unchanged.

All marks live inside the existing shot effect, use its age and color, and
scale with battlefield zoom. They add no particles, nodes, random gameplay
state, or damage events. Flight and impact durations are unchanged by this
visual upgrade. Pyre's ring uses the shot's existing splash radius.

Campaign combat and rendered terrain checks run with `./launch.ps1 -Check`.
