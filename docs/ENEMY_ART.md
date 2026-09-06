# Enemy artwork and Lantern Keeper

All four enemies use native Godot filled shapes and black outlines in the same
paper, mint, coral, lilac and gold palette as the towers. `enemy_art.gd` owns their
silhouettes; `VigilTerrainArt.enemy` is the shared battlefield/Field Guide entry.

| Enemy | Visual identity | Combat role |
| --- | --- | --- |
| Hollow | Cracked bone mask and frayed burial shroud | Existing common enemy; stats unchanged |
| Wraith | Swept hood, dark face and forked spectral tails | Existing fast enemy; stats unchanged |
| Revenant | Broad pauldrons, horned helmet and gold chest fissure | Existing durable enemy; stats unchanged |
| Lantern Keeper | Split violet robe, bone clasp and hand-carried ember lantern | 120 HP, 46 units/s, 14 gold |

Attune the Keeper for 140 gold at an owned rift. It occupies 16% of that rift's
traffic, replacing part of the Hollow share. With all types attuned the mix is
36% Hollow, 30% Wraith, 18% Revenant and 16% Keeper. Existing saves and unattuned
rifts keep their previous traffic. Keeper attunement uses the existing save
schema. It follows normal damage, targeting, routing and harmless-escape rules;
its lantern is visual, with no hidden buffs or status effects.

The Field Guide and developer controls read the same definition as combat.
Health bars sit above the taller silhouettes at every camera zoom.

`./launch.ps1 -ArtSmoke` regenerates transparent 256 x 256 reference PNGs in
`assets/enemies/` and `artifacts/enemy-lineup.png`, with enlarged portraits and
four actual gameplay zoom samples. Gameplay draws the native shapes directly.
The checks cover visible, distinct silhouettes and transparent frame padding.
`./launch.ps1 -Tests` covers every attunement combination, normal spawning,
Keeper movement, damage, once-only rewards, save reload, and mixed combat.
