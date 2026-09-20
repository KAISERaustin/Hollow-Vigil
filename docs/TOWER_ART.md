# Tower artwork

Every tower has three base visual stages and two level-four specializations.
`VigilTerrainArt.sentinel` accepts the saved tower level and branch; the
battlefield and tower dialog both display that stage.
`tower_tiers.gd` adds details to the original
base silhouettes, preserving the game's flat palette and black outlines.

| Tower | Level 2 | Level 3 |
| --- | --- | --- |
| Gloamwatch | Timber supports and top flag | Fortified buttresses and front banner |
| Obelisk | Rune and stone collar | Satellite crystals and floating capstone |
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

## Additional tower families

Ironspike, Moonwheel, Hex Lantern and Caltrop Keep compose the stateless native
`rendering/actors/expansion_tower_art.gd` family. Each has level-one, reinforced,
fortified and two final branch silhouettes. The same drawing owner supplies
battlefields, build previews, menu portraits and upgrade previews in Campaign.
The concept renderer now inherits this production owner rather than duplicating
its drawing code. It generates twenty transparent exports and review boards in ignored
`artifacts/tower-expansion/`.

`rendering/effects/tower_component_art.gd` draws actual live bolts, outward and
returning crescents, armed/unarmed road traps and orbiting blades from combat
state. Exposed enemies display an eye mark through the shared affliction renderer.
Game collision positions and visual positions share one owner; the cosmetic
effect limit cannot suppress projectile damage or trap triggers.

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

## Gloamwatch authored family

The five approved, aligned PNGs in `assets/artwork/tower/rapid/` replace the
legacy Ashneedle drawings at every zoom through `assets/artwork/catalog.json`.
Battlefields, build ghosts, build cards, tower dialogs and branch previews use
the same catalog. All stages share a ground anchor and 20 pixels per world unit;
none are individually cropped or fitted in play. Catalog portrait bounds keep
flags inside menu portraits. The baker preserves authored entries, including
when `--overwrite-native` is requested. See [the source family](concepts/gloamwatch/README.md)
for lore, the 16-color palette, exact alignment and generation history.
