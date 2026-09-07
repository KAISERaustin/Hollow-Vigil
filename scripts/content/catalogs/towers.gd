extends RefCounted

const TOWERS := {
	"rapid": {"name": "Ashneedle", "role": "RAPID", "cost": 60.0, "damage": 6.0, "period": 0.48, "range": 132.0, "splash": 0.0, "color": "e0b568", "description": "Swift pointed darts cut through hollows and wraiths."},
	"splash": {"name": "Pyre", "role": "SPLASH", "cost": 120.0, "damage": 15.0, "period": 1.5, "range": 126.0, "splash": 46.0, "color": "db8d73", "description": "Flame waves burst on impact, striking every enemy within the blast radius."},
	"heavy": {"name": "Obelisk", "role": "HEAVY", "cost": 160.0, "damage": 40.0, "period": 1.8, "range": 157.0, "splash": 0.0, "color": "b49dcc", "description": "Large magic orbs reach distant foes and deal heavy damage to resilient enemies."},
	"electric": {"name": "Stormspire", "role": "MULTI-TARGET", "cost": 140.0, "damage": 3.0, "period": 0.4, "range": 145.0, "splash": 0.0, "targets": 5, "color": "91bbff", "description": "Forked lightning zaps up to {targets} enemies at a time within reach, of any troop type."}
}

const PROJECTILES := {
	"rapid": {"muzzle": Vector2(0, -25), "speed": 760.0, "min_flight": 0.10, "max_flight": 0.22, "impact_time": 0.09},
	"splash": {"muzzle": Vector2(0, -29), "speed": 520.0, "min_flight": 0.17, "max_flight": 0.30, "impact_time": 0.24},
	"heavy": {"muzzle": Vector2(0, -22), "speed": 470.0, "min_flight": 0.18, "max_flight": 0.36, "impact_time": 0.18},
	"electric": {"muzzle": Vector2(0, -29), "speed": 760.0, "min_flight": 0.0, "max_flight": 0.0, "impact_time": 0.30}
}

const TOWER_UPGRADES := {
	"rapid": [
		{"cost": 60.0, "damage": 10.0, "period": 0.4, "range": 146.0, "splash": 0.0},
		{"cost": 100.0, "damage": 15.0, "period": 0.3, "range": 160.0, "splash": 0.0}
	],
	"splash": [
		{"cost": 120.0, "damage": 24.0, "period": 1.3, "range": 140.0, "splash": 56.0},
		{"cost": 200.0, "damage": 36.0, "period": 1.1, "range": 154.0, "splash": 66.0}
	],
	"heavy": [
		{"cost": 140.0, "damage": 60.0, "period": 1.35, "range": 173.0, "splash": 0.0},
		{"cost": 220.0, "damage": 90.0, "period": 0.9, "range": 189.0, "splash": 0.0}
	],
	"electric": [
		{"cost": 120.0, "damage": 5.0, "period": 0.35, "range": 159.0, "splash": 0.0, "targets": 5},
		{"cost": 200.0, "damage": 7.0, "period": 0.3, "range": 173.0, "splash": 0.0, "targets": 5}
	]
}

const BRANCHES := {
	"rapid": {
		"frostneedle": {"name": "Frostneedle", "color": "96d6e6", "cost": 180.0, "description": "Ice needles slow enemies by {slow_percent}% for {slow_duration} seconds. Repeated hits refresh the slow; they never stack."},
		"thorn_volley": {"name": "Poison Arrow", "color": "93b979", "cost": 180.0, "description": "Arrows poison their target for {duration} seconds, dealing {poison_dps} damage each second. Hits from this tower refresh the poison without stacking."}
	},
	"splash": {
		"cinderfield": {"name": "Cinderfield", "color": "f19b57", "cost": 320.0, "description": "Blasts leave burning ground for {burn_duration} seconds at {burn_dps} damage per second. Overlapping fire from this tower refreshes without stacking."},
		"rupture_pyre": {"name": "Rupture Pyre", "color": "e6a16d", "cost": 320.0, "description": "Blasts deal {damage} damage every {period} seconds and push enemies back {push_distance} units, reduced by enemy resistance. Enemies resist another push for {push_immunity} seconds."}
	},
	"heavy": {
		"grave_echo": {"name": "Grave Echo", "color": "c3a0ed", "cost": 360.0, "description": "A heavy orb bursts into {fragment_count} seeking fragments. Each deals {fragment_percent}% of its damage to a different enemy within {fragment_range} units. The original target is excluded; unused fragments fade."},
		"doomstone": {"name": "Doomstone", "color": "c282bb", "cost": 360.0, "description": "Consecutive hits on one enemy increase this tower's damage by {curse_percent}% per curse stack, up to {curse_max_percent}% bonus. Switching targets resets the curse."}
	},
	"electric": {
		"tempest_web": {"name": "Tempest Web", "color": "a9dce9", "cost": 300.0, "description": "Strikes up to {targets} enemies. Each strike arcs to one additional, distinct enemy within {arc_range} units for {arc_percent}% damage, reaching beyond normal range."},
		"thunderseal": {"name": "Thunderseal", "color": "b3b5f1", "cost": 300.0, "description": "After {seal_hits} hits from this tower, a seal detonates for {seal_damage} times hit damage as a bonus and a {stun_duration}-second stun. Charges reset; {stun_immunity}-second stun immunity prevents continuous lockdown."}
	}
}

const BRANCH_STAT_MULTIPLIERS := {
	"cinderfield": {"damage": 0.75},
	"rupture_pyre": {"damage": 1.5, "period": 1.5 / 1.1},
	"grave_echo": {"damage": 110.0 / 90.0}
}

const ABILITIES := {
	"frostneedle": {"slow_percent": 25.0, "slow_duration": 2.0},
	"thorn_volley": {"duration": 3.0, "dot_multiplier": 0.3333333333333333, "arrow_count": 5, "fan_angle": 0.96},
	"cinderfield": {"burn_duration": 3.0, "burn_multiplier": 0.4444444444444444},
	"rupture_pyre": {"push_distance": 20.0, "push_immunity": 1.0},
	"grave_echo": {"fragment_count": 5, "fragment_range": 90.0, "fragment_multiplier": 0.2},
	"doomstone": {"curse_limit": 5, "curse_multiplier": 0.2},
	"tempest_web": {"arc_range": 60.0, "arc_multiplier": 0.5},
	"thunderseal": {"seal_hits": 5, "seal_damage": 3.0, "stun_duration": 0.4, "stun_immunity": 2.0}
}

# Stable branch IDs keep existing saves and build codes readable. Legacy fan
# fields are accepted but no longer used by Poison Arrow.
const COMPONENTS := {"thorn_volley": ["damage_over_time"]}
