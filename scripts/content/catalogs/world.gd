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
	"mourning_orchard": {"name": "Mourning Orchard", "portal": "mourning_orchard", "min_tiles": 6, "max_tiles": 9}
}

const RIFTS := {
	"ashen_forge": {"name": "Forged Rift", "strength": 25.0},
	"drowned_crypt": {"name": "Drowned Rift", "strength": 15.0},
	"bloodmoon_sanctuary": {"name": "Bloodmoon Rift", "strength": 1.0}
}

# Portal nodes compose one roster, its purchase rules and its spawn weights.
# Legacy prices only validate/refund retired attunements when loading old saves.
const LEGACY_NORMAL_COSTS := {"fast": 90.0, "heavy": 180.0, "lantern": 140.0}
const PORTALS := {
	"forest": {"name": "Forest Rift", "unlock_costs": Actors.UNLOCK_COSTS, "shares": Actors.ENEMY_SHARES, "legacy_costs": LEGACY_NORMAL_COSTS},
	"ashen_forge": {"name": "Forged Rift", "unlock_costs": {"lantern": 140.0, "slag_golem": 180.0}, "shares": {"lantern": 0.30, "slag_golem": 0.18}, "legacy_costs": LEGACY_NORMAL_COSTS},
	"drowned_crypt": {"name": "Drowned Rift", "unlock_costs": {"mire_wraith": 90.0, "bell_hulk": 180.0}, "shares": {"mire_wraith": 0.30, "bell_hulk": 0.18}, "legacy_costs": LEGACY_NORMAL_COSTS},
	"bloodmoon_sanctuary": {"name": "Bloodmoon Rift", "unlock_costs": {"crescent_wisp": 90.0, "ruin_knight": 1100.0}, "shares": {"crescent_wisp": 0.30, "ruin_knight": 0.18}, "legacy_costs": LEGACY_NORMAL_COSTS},
	"castle_ruin": {"name": "Castle Ruin Portal", "unlock_costs": Actors.DUNGEON_UNLOCK_COSTS, "legacy_costs": {"sentinel": 550.0, "ruin_knight": 1100.0, "sepulcher": 2000.0}},
	"mourning_orchard": {"name": "Mourning Orchard Portal", "unlock_costs": {}, "allow_escorts": false, "legacy_costs": {}}
}
