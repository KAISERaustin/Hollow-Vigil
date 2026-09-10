extends RefCounted

const Actors = preload("res://scripts/content/catalogs/actors.gd")

const STYLES := ["forest", "ashen_forge", "drowned_crypt", "bloodmoon_sanctuary"]
const NEW_STYLES := ["ashen_forge", "drowned_crypt", "bloodmoon_sanctuary", "mourning_orchard"]
const ALL_STYLES := STYLES + ["castle_ruin", "mourning_orchard"]
const BIOME_BOSSES := {"forest": "warden", "ashen_forge": "cindermaw", "drowned_crypt": "bell", "bloodmoon_sanctuary": "prior", "castle_ruin": "ruined_king", "mourning_orchard": "mourning_matriarch"}
const PADS := [Vector2(-76, -76), Vector2(85, -78), Vector2(-79, 83), Vector2(83, 85)]
const REGION_DEFAULTS := {"road_version": 2, "traffic": 0, "timer": 0.25, "unlocks": [], "history": {}, "history_time": 0.0}
const LANDMARKS := {
	"castle": {"name": "Castle Ruin", "encounter": "boss", "buildable": false},
	"mourning_orchard": {"name": "Mourning Orchard", "portal": "mourning_orchard"}
}

const RIFTS := {
	"ashen_forge": {"name": "Forged Rift", "strength": 25.0},
	"drowned_crypt": {"name": "Drowned Rift", "strength": 15.0},
	"bloodmoon_sanctuary": {"name": "Bloodmoon Rift", "strength": 1.0}
}

# Initial ornaments preserve the chapter portals' base appearance.
const PORTALS := {
	"forest": {"name": "Forest Rift", "initial_ornaments": ["basic"]},
	"ashen_forge": {"name": "Forged Rift", "initial_ornaments": ["cinder_imp"]},
	"drowned_crypt": {"name": "Drowned Rift", "initial_ornaments": ["drowned_thrall"]},
	"bloodmoon_sanctuary": {"name": "Bloodmoon Rift", "initial_ornaments": ["blood_acolyte"]},
	"castle_ruin": {"name": "Castle Ruin Portal", "initial_ornaments": ["shade"]},
	"mourning_orchard": {"name": "Mourning Orchard Portal", "initial_ornaments": ["briarling", "veil_widow", "coffinbound"]}
}
