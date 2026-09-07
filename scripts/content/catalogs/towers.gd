extends RefCounted

# Optional presentation assignments inherited by every tier of a tower family.
const UPGRADE_SOUNDS := {"rapid": "upgrade_rapid"}

const TOWERS := {
	"rapid": {"name": "Ashneedle", "role": "RAPID", "cost": 60.0, "damage": 6.0, "period": 0.48, "range": 140.0, "splash": 0.0, "color": "e0b568", "description": "Swift pointed darts cut through hollows and wraiths."},
	"splash": {"name": "Pyre", "role": "SPLASH", "cost": 120.0, "damage": 15.0, "period": 1.5, "range": 115.0, "splash": 46.0, "color": "db8d73", "description": "Flame waves burst on impact, striking every enemy within the blast radius."},
	"heavy": {"name": "Obelisk", "role": "HEAVY", "cost": 160.0, "damage": 40.0, "period": 1.8, "range": 185.0, "splash": 0.0, "color": "b49dcc", "description": "Large magic orbs reach distant foes and deal heavy damage to resilient enemies."},
	"electric": {"name": "Stormspire", "role": "MULTI-TARGET", "cost": 140.0, "damage": 3.0, "period": 0.4, "range": 160.0, "splash": 0.0, "targets": 5, "color": "91bbff", "description": "Forked lightning zaps up to {targets} enemies at a time within reach, of any troop type."},
	"ironspike": {"name": "Ironspike", "role": "PIERCING", "cost": 140.0, "damage": 22.0, "period": 1.4, "range": 200.0, "splash": 0.0, "color": "ede4c9", "pierce_count": 3, "pierce_loss": 0.3, "pierce_floor": 0.5, "projectile_width": 9.0, "volley_count": 1, "volley_spacing": 20.0, "description": "A straight bolt pierces up to {pierce_count} aligned enemies, losing damage after each hit. Best beside long straight roads."},
	"moonwheel": {"name": "Moonwheel", "role": "RETURNING", "cost": 130.0, "damage": 10.0, "period": 1.5, "range": 135.0, "splash": 0.0, "color": "93c9bc", "pierce_count": 3, "projectile_width": 12.0, "return_speed": 1.0, "description": "A crescent cuts out and back through up to {pierce_count} enemies per pass. Each enemy can take one hit on each leg; only one blade flies at a time."},
	"hex_lantern": {"name": "Hex Lantern", "role": "SUPPORT", "cost": 100.0, "damage": 4.0, "period": 1.4, "range": 270.0, "splash": 0.0, "color": "c28cab", "vulnerability_percent": 12.0, "mark_duration": 2.0, "description": "Curse bolts mark enemies for {mark_duration} seconds, increasing all tower damage received by {vulnerability_percent}%. Only the strongest vulnerability applies."},
	"caltrop_keep": {"name": "Caltrop Keep", "role": "ROAD TRAPS", "cost": 120.0, "damage": 24.0, "period": 2.0, "range": 125.0, "splash": 0.0, "color": "db8d73", "trap_capacity": 3, "trap_duration": 8.0, "trap_arm_time": 0.5, "trap_count": 1, "trap_radius": 12.0, "description": "Deploys single-use caltrops on nearby roads. Stores up to {trap_capacity}; each arms in {trap_arm_time} seconds and expires after {trap_duration} seconds. Traps never block movement."}
}

const PROJECTILES := {
	"rapid": {"muzzle": Vector2(0, -25), "speed": 760.0, "min_flight": 0.10, "max_flight": 0.22, "impact_time": 0.09},
	"splash": {"muzzle": Vector2(0, -29), "speed": 520.0, "min_flight": 0.17, "max_flight": 0.30, "impact_time": 0.24},
	"heavy": {"muzzle": Vector2(0, -22), "speed": 470.0, "min_flight": 0.18, "max_flight": 0.36, "impact_time": 0.18},
	"electric": {"muzzle": Vector2(0, -29), "speed": 760.0, "min_flight": 0.0, "max_flight": 0.0, "impact_time": 0.30},
	"ironspike": {"muzzle": Vector2(0, -30), "speed": 420.0, "min_flight": 0.1, "max_flight": 0.6, "impact_time": 0.12},
	"moonwheel": {"muzzle": Vector2(0, -32), "speed": 260.0, "min_flight": 0.1, "max_flight": 0.6, "impact_time": 0.12},
	"hex_lantern": {"muzzle": Vector2(0, -23), "speed": 400.0, "min_flight": 0.1, "max_flight": 0.4, "impact_time": 0.2},
	"caltrop_keep": {"muzzle": Vector2(0, -8), "speed": 360.0, "min_flight": 0.1, "max_flight": 0.4, "impact_time": 0.15}
}

const TOWER_UPGRADES := {
	"rapid": [
		{"cost": 60.0, "damage": 10.0, "period": 0.4, "range": 154.0, "splash": 0.0},
		{"cost": 100.0, "damage": 15.0, "period": 0.3, "range": 168.0, "splash": 0.0}
	],
	"splash": [
		{"cost": 120.0, "damage": 24.0, "period": 1.3, "range": 129.0, "splash": 56.0},
		{"cost": 200.0, "damage": 36.0, "period": 1.1, "range": 143.0, "splash": 66.0}
	],
	"heavy": [
		{"cost": 140.0, "damage": 60.0, "period": 1.35, "range": 201.0, "splash": 0.0},
		{"cost": 220.0, "damage": 90.0, "period": 0.9, "range": 217.0, "splash": 0.0}
	],
	"ironspike": [
		{"cost": 120.0, "damage": 32.0, "period": 1.25, "range": 215.0, "splash": 0.0, "pierce_count": 4, "pierce_loss": 0.2, "pierce_floor": 0.4},
		{"cost": 200.0, "damage": 44.0, "period": 1.1, "range": 230.0, "splash": 0.0, "pierce_count": 5, "pierce_loss": 0.15, "pierce_floor": 0.4}
	],
	"moonwheel": [
		{"cost": 120.0, "damage": 15.0, "period": 1.35, "range": 145.0, "splash": 0.0, "pierce_count": 4, "return_speed": 1.2},
		{"cost": 200.0, "damage": 21.0, "period": 1.2, "range": 155.0, "splash": 0.0, "pierce_count": 5, "return_speed": 1.4, "projectile_width": 16.0}
	],
	"hex_lantern": [
		{"cost": 100.0, "damage": 7.0, "period": 1.2, "range": 300.0, "splash": 0.0, "vulnerability_percent": 16.0, "mark_duration": 2.5},
		{"cost": 180.0, "damage": 10.0, "period": 1.0, "range": 330.0, "splash": 0.0, "vulnerability_percent": 20.0, "mark_duration": 3.0, "targets": 2}
	],
	"caltrop_keep": [
		{"cost": 120.0, "damage": 36.0, "period": 1.8, "range": 140.0, "splash": 0.0, "trap_capacity": 4, "trap_duration": 10.0},
		{"cost": 200.0, "damage": 52.0, "period": 1.6, "range": 155.0, "splash": 0.0, "trap_capacity": 5, "trap_duration": 12.0}
	],
	"electric": [
		{"cost": 120.0, "damage": 5.0, "period": 0.35, "range": 174.0, "splash": 0.0, "targets": 5},
		{"cost": 200.0, "damage": 7.0, "period": 0.3, "range": 188.0, "splash": 0.0, "targets": 5}
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
	"ironspike": {
		"siegebreaker": {"name": "Siegebreaker", "color": "ede4c9", "cost": 320.0, "description": "Heavy bolts pierce {pierce_count} enemies at full damage. Boss hits deal {boss_damage_multiplier} times damage before defenses. A slower reload rewards focus fire."},
		"needle_battery": {"name": "Needle Battery", "color": "e0b568", "cost": 320.0, "description": "Fires {volley_count} parallel bolts, each piercing {pierce_count} enemies. A victim takes at most one hit per volley; wider coverage trades away single-target force."}
	},
	"moonwheel": {
		"reaper_wheel": {"name": "Reaper Wheel", "color": "93c9bc", "cost": 300.0, "description": "A giant serrated crescent cuts through {pierce_count} enemies on each leg. Its broad, long corridor and slower throws reward dense traffic."},
		"orbit_crown": {"name": "Orbit Crown", "color": "93c9bc", "cost": 300.0, "description": "Three blades orbit in a short radius, sweeping all nearby enemies every {period} seconds. Each enemy takes one hit per sweep, never one hit per blade."}
	},
	"hex_lantern": {
		"oathbrand": {"name": "Oathbrand", "color": "c28cab", "cost": 280.0, "description": "Concentrates on one enemy: +{vulnerability_percent}% incoming tower damage for {mark_duration} seconds. Only the strongest mark applies; boss defenses remain intact."},
		"witchlight": {"name": "Witchlight", "color": "b49dcc", "cost": 280.0, "description": "Marks add {vulnerability_percent}% incoming damage. A directly marked death spreads the mark to {mark_spread_count} nearby enemies for {mark_duration} seconds. Spread marks never spread again."}
	},
	"caltrop_keep": {
		"dreadjaw": {"name": "Dreadjaw", "color": "ede4c9", "cost": 320.0, "description": "Stores {trap_capacity} heavy jaw traps. Each deals {damage} damage to one victim, arms in {trap_arm_time} seconds, and expires after {trap_duration} seconds."},
		"scatterworks": {"name": "Scatterworks", "color": "e0b568", "cost": 320.0, "description": "Deploys {trap_count} weaker caltrops per cycle at separate road positions. Stores up to {trap_capacity}; each damages one victim and disappears."}
	},
	"electric": {
		"tempest_web": {"name": "Tempest Web", "color": "a9dce9", "cost": 300.0, "description": "Strikes up to {targets} enemies. Each strike arcs to one additional, distinct enemy within {arc_range} units for {arc_percent}% damage, reaching beyond normal range."},
		"thunderseal": {"name": "Thunderseal", "color": "b3b5f1", "cost": 300.0, "description": "After {seal_hits} hits from this tower, a seal detonates for {seal_damage} times hit damage as a bonus and a {stun_duration}-second stun. Charges reset; {stun_immunity}-second stun immunity prevents continuous lockdown."}
	}
}

const BRANCH_STAT_MULTIPLIERS := {
	"cinderfield": {"damage": 0.75},
	"rupture_pyre": {"damage": 1.5, "period": 1.5 / 1.1},
	"grave_echo": {"damage": 110.0 / 90.0},
	"siegebreaker": {"damage": 60.0 / 44.0, "period": 1.25 / 1.1, "range": 250.0 / 230.0},
	"needle_battery": {"damage": 28.0 / 44.0},
	"reaper_wheel": {"damage": 32.0 / 21.0, "period": 1.5 / 1.2, "range": 185.0 / 155.0},
	"orbit_crown": {"damage": 12.0 / 21.0, "period": 0.45 / 1.2, "range": 75.0 / 155.0},
	"dreadjaw": {"damage": 140.0 / 52.0, "period": 2.0 / 1.6},
	"scatterworks": {"damage": 32.0 / 52.0, "period": 2.0 / 1.6}
}

const ABILITIES := {
	"frostneedle": {"slow_percent": 25.0, "slow_duration": 2.0},
	"thorn_volley": {"duration": 3.0, "dot_multiplier": 0.3333333333333333, "arrow_count": 5, "fan_angle": 0.96},
	"cinderfield": {"burn_duration": 3.0, "burn_multiplier": 0.4444444444444444},
	"rupture_pyre": {"push_distance": 20.0, "push_immunity": 1.0},
	"grave_echo": {"fragment_count": 5, "fragment_range": 90.0, "fragment_multiplier": 0.2},
	"doomstone": {"curse_limit": 5, "curse_multiplier": 0.2},
	"tempest_web": {"arc_range": 60.0, "arc_multiplier": 0.5},
	"thunderseal": {"seal_hits": 5, "seal_damage": 3.0, "stun_duration": 0.4, "stun_immunity": 2.0},
	"siegebreaker": {"pierce_count": 3, "pierce_loss": 0.0, "pierce_floor": 1.0, "boss_damage_multiplier": 1.5},
	"needle_battery": {"pierce_count": 4, "volley_count": 3},
	"reaper_wheel": {"pierce_count": 8, "projectile_width": 22.0},
	"orbit_crown": {},
	"oathbrand": {"targets": 1, "vulnerability_percent": 35.0, "mark_duration": 4.0},
	"witchlight": {"mark_spread_count": 3, "mark_spread_radius": 80.0},
	"dreadjaw": {"trap_capacity": 3, "trap_arm_time": 1.0},
	"scatterworks": {"trap_count": 3, "trap_capacity": 9}
}

## Tower capabilities compose the same immutable Attribute family as gear.
## Branch assignments replace named slots; all unlisted slots are inherited.
const ATTACHMENTS := {
	"ironspike": {"attack": "piercing_attack"},
	"moonwheel": {"attack": "returning_attack"},
	"hex_lantern": {"mark": "vulnerability_mark"},
	"caltrop_keep": {"attack": "road_traps"},
	"siegebreaker": {"boss_bonus": "tower_boss_damage"},
	"orbit_crown": {"attack": "orbit_attack"}
}

# Stable branch IDs keep existing saves and build codes readable. Legacy fan
# fields are accepted but no longer used by Poison Arrow.
const COMPONENTS := {"thorn_volley": ["damage_over_time"]}
