extends RefCounted

## Presentation recipes composed by Chapter Level nodes. No simulation state.
## Any chapter can replace/remove its map_landscape attachment independently.
const PROFILES := {
	"forest": {"landmarks": ["watchtower", "watermill", "ruins", "watchtower"], "scenery": ["pines", "pines", "pool", "cart"], "stone": "d4ccb0", "roof": "48695c", "water": "699b99", "motif": "leaf"},
	"ashen_forge": {"landmarks": ["foundry", "fortress", "foundry", "ruins"], "scenery": ["crags", "crags", "cart", "slag"], "stone": "cba58b", "roof": "655952", "water": "b96345", "motif": "anvil"},
	"drowned_crypt": {"landmarks": ["belfry", "ruins", "belfry", "watermill"], "scenery": ["pool", "tombs", "pool", "reeds"], "stone": "c3d0c2", "roof": "4a6e79", "water": "527f8c", "motif": "bell"},
	"bloodmoon_sanctuary": {"landmarks": ["observatory", "belfry", "observatory", "fortress"], "scenery": ["cypress", "ruins", "pool", "tombs"], "stone": "ddc9ca", "roof": "625671", "water": "78657d", "motif": "crescent"},
	"castle_ruin": {"landmarks": ["fortress", "ruins", "watchtower", "fortress"], "scenery": ["crags", "ruins", "cart", "cypress"], "stone": "bcb8ad", "roof": "515663", "water": "546777", "motif": "shield"},
	"mourning_orchard": {"landmarks": ["orchard_shrine", "watermill", "orchard_shrine", "ruins"], "scenery": ["orchard", "orchard", "tombs", "pool"], "stone": "d8cead", "roof": "68734f", "water": "7c9681", "motif": "veil"}
}
