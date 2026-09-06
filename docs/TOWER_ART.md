# Tower artwork

Every tower has three visual stages. `VigilTerrainArt.sentinel` accepts the
saved tower level; the battlefield and tower dialog both display that stage.
The field guide uses level one. `tower_tiers.gd` adds details to the original
base silhouettes, preserving the game's flat palette and black outlines.

| Tower | Level 2 | Level 3 |
| --- | --- | --- |
| Ashneedle | Reinforced collar and side needles | Needle crown and wing armor |
| Obelisk | Rune and stone collar | Satellite crystals and floating capstone |
| Pyre | Banded brazier and white-hot core | Side braziers and fire crown |
| Stormspire | Conductive bands and charged tips | Outer lightning rods and arcing crown |

The twelve transparent 256 x 256 PNGs in `assets/towers/` are rendered from
the same native Godot artwork used in play, with consistent framing. No AI
image-generation prompt or external image model is used. Regenerate them with
`./launch.ps1 -ArtSmoke`, which also saves a comparison sheet and poof screenshot
under `artifacts/` and checks distinct tiers, transparent padding, upgrade
events, rejected upgrades, expiration, and state replacement.

A successful economy upgrade emits `tower_upgraded`. The battlefield displays
a 0.65-second expanding dust cloud and tower-colored motes at that socket.
Effects use frame time and map coordinates, follow camera zoom and pan, and
never enter saved progress. Failed, stale, and maximum-level upgrades emit no
effect. Replacing the economy disconnects the previous signal and clears poofs.
