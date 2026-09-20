# Tower artwork

Every tower has three base visual stages and two level-four specializations.
`VigilTerrainArt.sentinel` accepts the saved tower level and branch; the
battlefield and tower dialog both display that stage.
`tower_tiers.gd` adds details to the original
base silhouettes, preserving the game's flat palette and black outlines.

| Tower | Level 2 | Level 3 |
| --- | --- | --- |
| Gloamwatch (Ashneedle artwork) | Braced side firing galleries | Iron-clad central shelter |
| Obelisk | Two carved binding buttresses | Supported angular binding arch |
| Pyre | Stone buttresses, reinforced collar and hotter roof fire | Twin flame sconces around the battlements |
| Stormspire | Paired iron conductor arms | Two smaller forked staffs on those arms |

Pyre's base is a tall coral-stone watchtower with masonry seams, a crenellated
parapet, a black arched furnace and an ochre/ember roof flame. Its reusable,
stateless `fire_tower_art.gd` component composes the same shaft, battlements,
furnace, flames and sconces for all five appearances. Cinderfield adds charred
stone and ember seams; Rupture Pyre adds riveted iron piers and a barred furnace.
Both retain the tower silhouette. The battlefield, build previews, portraits
and upgrade previews all call the shared sentinel renderer. Combat stats,
projectile outlets, placement and saved tower identities are unchanged.
The artwork family supplies portrait bounds to `sentinel_portrait`, which
centers and fits the taller fire crown inside both medallions and dialog headers.

The tower upgrade art runner generates twelve transparent 256 x 256 PNGs in
ignored `artifacts/towers/` from
the same native Godot artwork used in play, with consistent framing. No AI
image-generation prompt or external image model is used. `./launch.ps1 -ArtSmoke` checks Hex effects, upgrade events, rejected upgrades, effect expiration and state replacement. The standalone tower upgrade art runner checks transparent padding and stage artwork. Captures are written under `artifacts/`.

A successful economy upgrade emits `tower_upgraded`. The battlefield displays
a 0.65-second expanding dust cloud and tower-colored motes at that socket.
Effects use frame time and map coordinates, follow camera zoom and pan, and
never enter saved progress. Failed, stale, and maximum-level upgrades emit no
effect. Replacing the economy disconnects the previous signal and clears poofs.

## Obelisk authored family

The Rune Monolith sprites in `assets/artwork/tower/heavy/` are unchanged copies
of the approved five-sprite family. Oathbind supplies Grave Echo; Doomseal
supplies Doomstone. The shared authored catalog serves battlefield towers,
placement ghosts, build choices, portraits, upgrade previews, and high zoom.
Native rebaking preserves these entries. Each sprite uses 20 pixels per world
unit and source ground anchor (627, 1156), with a spell outlet at (627, 500).
Catalog portrait bounds include both complete branch silhouettes.

Active Doomstone curse markers use named presentation anchors at the carved
runes. They follow the existing curse state and clear when that state expires.
All combat values, branch identities, save data, and placement rules are retained.
The focused `rendered/obelisk_art_runner.gd` passed 123 checks, with battlefield
and portrait inspection at 360x640, 390x844, and 540x960. See
[the source family](concepts/rune-monolith-2026-09-20/README.md) for palette,
layer preservation, alignment, and runtime mapping.

## Additional tower families

Legacy native silhouettes remain in the stateless
`rendering/actors/expansion_tower_art.gd` family. Authored catalog entries take
precedence in battlefields, build previews, menu portraits, upgrade previews,
and export rendering. The historical concept renderer reuses the native owner
for its transparent exports and review boards in `artifacts/tower-expansion/`.

`rendering/effects/tower_component_art.gd` draws actual live bolts, outward and
returning crescents, armed/unarmed road traps and orbiting blades from combat
state. Exposed enemies display an eye mark through the shared affliction renderer.
Game collision positions and visual positions share one owner; the cosmetic
effect limit cannot suppress projectile damage or trap triggers.

## Caltrop Keep authored family

The five approved Sapper's Hold sprites are installed unchanged in
`assets/artwork/tower/caltrop_keep/`. Broadscatter Arsenal supplies Scatterworks;
Ironthorn Hold supplies Dreadjaw. Existing trap behavior, stats, branch names and
save identities remain intact. All stages share source anchor `(627, 1122)` at
world `(0, 0)` and 20 pixels per world unit, preserving the hold's core width
through upgrades. Per-stage catalog bounds frame each full portrait.

The shared battlefield, build ghosts, menu portraits, upgrades and export path
use these authored entries at every zoom; native rebaking skips them. The
focused `rendered/caltrop_keep_art_runner.gd` passed 88 checks for source hashes,
fixed scale/ground, normal/high zoom, export drawing, and 48/80-pixel portraits.
All five stages were visually checked at 360x640, 390x844 and 540x960. See
[the source family](concepts/caltrop-keep-2026-09-20/README.md) for palette,
placement and branch mapping. This is desktop render validation.

## Moonwheel authored family

All five Crescent Reliquary sprites are installed unchanged in
`assets/artwork/tower/moonwheel/`. Tiers 1-3 keep their existing identities;
Reaping Arc supplies Reaper Wheel and Oathbound Return supplies Orbit Crown.
The existing names, saved branch IDs, stats and attack components remain intact.

The catalog uses one 20-pixels-per-world-unit transform with source ground
anchor `(626.5, 1120)`. Per-stage portrait bounds include the complete bronze
vanes and high stone arch. Authored entries remain active at every zoom and are
protected from native rebaking. The cached alpha cutoff removes faint background
residue without changing source files. Returning blades launch from the crescent
at source pixel `(550, 500)` through the shared projectile profile.

`rendered/moonwheel_art_runner.gd` passed 125 checks: exact source copies,
ground/muzzle alignment, outward and return hits, existing Orbit Crown behavior,
normal/high zoom and export rendering, and 32/42/48/64/80-pixel portraits.
Battlefield/portrait captures were visually inspected at 360x640, 390x844 and
540x960. This is desktop rendering and simulation coverage. See
[the source family](concepts/moonwheel-crescent-reliquary/README.md).

## Hex Lantern authored family

The five Witchlight Shrine sprites are installed in
`assets/artwork/tower/hex_lantern/` through the shared authored artwork catalog.
The curse-lantern sprite supplies Witchlight; the green sword/staff shield sprite
supplies Oathbrand. The existing tower and branch IDs, stats, saves, hexes, and
auras remain intact. Every image is an unchanged copy of the approved source.

All stages share 16 pixels per world unit and source ground anchor (627, 1156).
The spell outlet is the central violet light at source pixel (627, 896).
Battlefield towers, placement ghosts, build choices, rules portraits, tower
dialogs, and upgrade previews use these images, including at high zoom. The
catalog supplies each stage's complete portrait bounds; native rebaking skips
the authored entries. See [the source family](concepts/hex-lantern-witchlight-2026-09-20/README.md).

`rendered/hex_lantern_art_runner.gd` passed 108 checks for source hashes,
anchor/outlet placement, actual spell creation, all five stages at normal/high
zoom, export rendering, and 32/42/48/64/80-pixel portraits. Battlefield/portrait
captures were visually checked at 360x640, 390x844, and 540x960. The 66 Hex support
checks and combined-affliction/aura renders also passed. This is desktop
validation; physical iOS/Android testing was not performed.

## Stormspire authored family

All five approved Tempest Spire PNGs are installed in
`assets/artwork/tower/electric/`. The catalog uses one 20-pixels-per-world-unit
transform and ground anchor for all stages, plus complete portrait framing.
Skyfork supplies Tempest Web's image; Thunderward supplies Thunderseal's image.
These authored entries remain active at every zoom and survive native rebaking.
Battlefields, build ghosts, portraits and upgrade previews use the same images.
The lightning outlet matches the staff's blue inset while enemy-to-enemy chain
arcs retain their proper origin. See [the source family](concepts/stormspire-tempest-new/README.md)
for the exact palette, source pixels, alignment and runtime mapping.

## Ashneedle / Gloamwatch authored family

The five approved Arrow Watchtower sprites in `assets/artwork/tower/rapid/`
are byte-identical copies of [the Ashneedle source family](concepts/ashneedle-original-2026-09-20/README.md).
The existing tower still displays as Gloamwatch; names, mechanics and save IDs
are preserved. Arrowstorm supplies Frostneedle's image and Lastwatch supplies
Poison Arrow's image. Battlefields, build ghosts, build cards, tower dialogs and
branch previews share `assets/artwork/catalog.json` at every zoom.

All stages use 18 pixels per world unit and source ground anchor (627, 1128).
The existing arrow outlet falls inside the common dark firing opening. Catalog
portrait bounds include the complete bows, pennants and elevated lookout.
No source is cropped or resized. The baker preserves these authored entries,
including when `--overwrite-native` is requested.

`rendered/gloamwatch_runner.gd` covers all five source hashes, anchors, outlets,
portrait framing and runtime/export rendering at normal and high zoom. It
captures battlefield sprites and portraits at 360x640, 390x844 and 540x960.
