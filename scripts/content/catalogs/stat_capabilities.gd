extends RefCounted

## Capabilities own their dependent values. Identity is independent of recipient.
const TOWER := {
	"piercing_attack": {"name": "Piercing bolts", "group": "Abilities", "primary": true, "fields": {"pierce_count": 3, "pierce_loss": 0.3, "pierce_floor": 0.5, "projectile_width": 9.0, "volley_count": 1, "volley_spacing": 20.0}},
	"returning_attack": {"name": "Returning blade", "group": "Abilities", "primary": true, "fields": {"pierce_count": 3, "projectile_width": 12.0, "return_speed": 1.0}},
	"orbit_attack": {"name": "Orbiting blades", "group": "Abilities", "primary": true, "fields": {}},
	"road_traps": {"name": "Road traps", "group": "Abilities", "primary": true, "fields": {"trap_capacity": 3, "trap_duration": 8.0, "trap_arm_time": 0.5, "trap_count": 1, "trap_radius": 12.0}},
	"frostneedle": {"name": "Ice slow", "group": "Abilities", "fields": {"slow_percent": 25.0, "slow_duration": 2.0}},
	"thorn_volley": {"name": "Poison", "group": "Abilities", "fields": {"duration": 3.0, "dot_multiplier": 0.3333333333333333}},
	"cinderfield": {"name": "Burning ground", "group": "Abilities", "fields": {"burn_duration": 3.0, "burn_multiplier": 0.4444444444444444}},
	"rupture_pyre": {"name": "Knockback", "group": "Abilities", "fields": {"push_distance": 20.0, "push_immunity": 1.0}},
	"grave_echo": {"name": "Seeking fragments", "group": "Abilities", "fields": {"fragment_count": 5, "fragment_range": 90.0, "fragment_multiplier": 0.2}},
	"doomstone": {"name": "Focused curse", "group": "Abilities", "fields": {"curse_limit": 5, "curse_multiplier": 0.2}},
	"tempest_web": {"name": "Chain lightning", "group": "Abilities", "fields": {"arc_range": 60.0, "arc_multiplier": 0.5}},
	"thunderseal": {"name": "Charged seal", "group": "Abilities", "fields": {"seal_hits": 5, "seal_damage": 3.0, "stun_duration": 0.4, "stun_immunity": 2.0}},
	"vulnerability_mark": {"name": "Hex mark", "group": "Abilities", "fields": {"vulnerability_percent": 75.0, "mark_duration": 6.0, "mark_spread_count": 0, "mark_spread_radius": 80.0}},
	"damage_aura": {"name": "Nearby tower damage aura", "group": "Attributes", "fields": {"aura_damage_percent": 8.0}},
	"tower_boss_damage": {"name": "Bonus boss damage", "group": "Attributes", "fields": {"boss_damage_multiplier": 1.5}}
}
const ENEMY := {
	"shield": {"name": "Protective shield", "group": "Abilities", "fields": {"shield": 600.0, "fire_multiplier": 2.0}},
	"wards": {"name": "Protective wards", "group": "Abilities", "fields": {"wards": 3, "doom_bypass": 1}},
	"regrowth": {"name": "Defense regrowth", "group": "Abilities", "fields": {"regen_period": 10.0, "regrowth_suppression": 100.0, "curse_threshold": 5}},
	"rage": {"name": "Wounded haste and armor", "group": "Abilities", "fields": {"rage_threshold": 50.0, "haste_multiplier": 1.7, "armor_reduction": 30.0, "frost_multiplier": 1.5, "quench": 100.0}},
	"summon": {"name": "Summon escorts", "group": "Abilities", "fields": {"toll_period": 8.0, "escort_kind": 0, "escort_count": 3, "escort_limit": 6, "seal_multiplier": 4.5, "toll_delay": 2.0}}
}
const RESISTANCES := {"poison_resistance": "Poison resistance", "ice_resistance": "Ice resistance", "hex_resistance": "Hex resistance", "push_resistance": "Knockback resistance"}

static func defaults(category: String, kind: String) -> Array:
	if category == "bosses":
		return {"warden": ["shield"], "prior": ["wards", "regrowth"], "cindermaw": ["rage"], "bell": ["summon"]}.get(kind, []).duplicate()
	if category != "towers": return []
	var base := kind.get_slice(":", 0)
	var branch := kind.get_slice(":", 1)
	var result: Array = {"ironspike": ["piercing_attack"], "moonwheel": ["returning_attack"], "caltrop_keep": ["road_traps"], "hex_lantern": ["vulnerability_mark", "damage_aura"]}.get(base, []).duplicate()
	if branch == "orbit_crown": result = ["orbit_attack"]
	if branch == "siegebreaker": result.append("tower_boss_damage")
	if branch in ["frostneedle", "thorn_volley", "cinderfield", "rupture_pyre", "grave_echo", "doomstone", "tempest_web", "thunderseal"]: result.append(branch)
	return result
