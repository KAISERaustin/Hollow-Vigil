extends RefCounted

const STYLES := ["forest", "ashen_forge", "drowned_crypt", "bloodmoon_sanctuary"]
const NEW_STYLES := ["ashen_forge", "drowned_crypt", "bloodmoon_sanctuary", "mourning_orchard"]
const ALL_STYLES := STYLES + ["castle_ruin", "mourning_orchard"]
const PADS := [Vector2(-76, -76), Vector2(85, -78), Vector2(-79, 83), Vector2(83, 85)]
const REGION_DEFAULTS := {"road_version": 2, "traffic": 0, "timer": 0.25, "unlocks": [], "history": {}, "history_time": 0.0}
const LANDMARKS := {
	"castle": {"name": "Castle Ruin", "encounter": "boss", "buildable": false},
	"mourning_orchard": {"name": "Mourning Orchard", "portal": "mourning_orchard", "min_tiles": 6, "max_tiles": 9}
}

const RIFTS := {
	"ashen_forge": {"name": "Forged Rift", "strength": 25.0},
	"drowned_crypt": {"name": "Drowned Rift", "strength": 15.0},
	"bloodmoon_sanctuary": {"name": "Bloodmoon Rift", "strength": 1.0}
}
