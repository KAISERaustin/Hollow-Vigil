class_name Balance
extends RefCounted

const VERSION := 2
const TARGET_MODES := {"first": "First", "last": "Last", "most_hp": "Most HP"}
const TILE := 300.0
const MAX_MONEY := 1.0e150
const STEP := 0.05
const HISTORY_SECONDS := 180.0
const OFFLINE_FACTOR := 0.8
const MAX_OFFLINE_SECONDS := 604800.0 # Seven-day guard against large forward clock jumps.
const STARTING_GOLD := 280.0 # First territory costs 100, leaving 180 for defenses.
const BASE_SPAWN_PERIOD := 4.25 # 40% of the former 1.7-second spawn rate at every traffic tier.
const TRAFFIC_INCREMENT := 0.25
const MAX_TRAFFIC_LEVEL := 12
const MAX_TOWER_LEVEL := 4
const TRAFFIC_BASE_COST := 80.0
const TRAFFIC_COST_GROWTH := 1.8
const AUTOMATION_COST := 600.0
const SELL_REFUND_RATIO := 0.5
const MOVE_COST_RATIO := 0.2
const MAX_REBUILD_SECONDS := 180.0
const REBUILD_SECONDS_PER_LEVEL := 15.0
const MIN_PRODUCTION_SAMPLE := 60.0
const UNLOCK_COSTS := {"fast": 90.0, "heavy": 180.0, "lantern": 140.0}
const ENEMY_SHARES := {"fast": 0.30, "heavy": 0.18, "lantern": 0.16}
const ENEMIES := {
	"basic": {"name": "Hollow", "role": "COMMON", "description": "A steady traveler from every rift. Its sturdy body rewards upgrading your sentinels.", "hp": 45.0, "speed": 39.0, "payout": 5.0, "color": "e8ddbd"},
	"fast": {"name": "Wraith", "role": "FAST", "description": "A swift spirit with less health than other foes. Its speed gives your towers less time to strike before it reaches the core.", "hp": 36.0, "speed": 74.0, "payout": 8.0, "color": "93c9bc"},
	"heavy": {"name": "Revenant", "role": "DURABLE", "description": "A slow, resilient foe with a rich bounty. High-damage towers help cut through its large health pool.", "hp": 340.0, "speed": 25.0, "payout": 24.0, "color": "db8d73"},
	"lantern": {"name": "Lantern Keeper", "role": "STEADFAST", "description": "A hooded pilgrim carrying a stolen ember through the rifts. Tougher than a Hollow and quicker than a Revenant, it rewards sustained fire with a generous bounty.", "hp": 120.0, "speed": 46.0, "payout": 14.0, "color": "b49dcc"}
}
const BOSSES := {
	"warden": {"name": "Briarbound Warden", "hp": 3200.0, "speed": 27.0, "payout": 450.0, "color": "95aa83", "weakness": "Cinderfield: burns roots; blocks regrowth", "shield": 600.0, "regen_period": 10.0, "fire_multiplier": 2.0, "regrowth_suppression": 100.0},
	"cindermaw": {"name": "Cindermaw", "hp": 3600.0, "speed": 25.0, "payout": 500.0, "color": "db8d73", "weakness": "Frostneedle: +50% damage; quenches haste", "rage_threshold": 50.0, "haste_multiplier": 1.7, "armor_reduction": 30.0, "frost_multiplier": 1.5, "quench": 100.0},
	"bell": {"name": "The Drowned Bell", "hp": 2800.0, "speed": 32.0, "payout": 450.0, "color": "93c9bc", "weakness": "Thunderseal: stronger seals; delays tolls", "toll_period": 8.0, "escort_count": 3, "escort_limit": 6, "seal_multiplier": 4.5, "toll_delay": 2.0},
	"prior": {"name": "The Eclipse Prior", "hp": 3000.0, "speed": 30.0, "payout": 500.0, "color": "b49dcc", "weakness": "Doomstone: bypasses wards; curses regrowth", "wards": 3, "regen_period": 10.0, "doom_bypass": 1, "curse_threshold": 5, "regrowth_suppression": 100.0}
}

const TOWERS := {
	"rapid": {"name": "Ashneedle", "role": "RAPID", "cost": 60.0, "damage": 6.0, "period": 0.48, "range": 132.0, "splash": 0.0, "color": "e0b568", "description": "Swift pointed darts cut through hollows and wraiths."},
	"splash": {"name": "Pyre", "role": "SPLASH", "cost": 120.0, "damage": 15.0, "period": 1.5, "range": 126.0, "splash": 46.0, "color": "db8d73", "description": "Flame waves burst on impact, striking every enemy within the blast radius."},
	"heavy": {"name": "Obelisk", "role": "HEAVY", "cost": 160.0, "damage": 40.0, "period": 1.8, "range": 157.0, "splash": 0.0, "color": "b49dcc", "description": "Large magic orbs reach distant foes and deal heavy damage to resilient enemies."},
	"electric": {"name": "Stormspire", "role": "MULTI-TARGET", "cost": 140.0, "damage": 3.0, "period": 0.4, "range": 145.0, "splash": 0.0, "targets": 5, "color": "91bbff", "description": "Forked lightning zaps up to five enemies at a time within reach, of any troop type. The five-target limit stays the same at every level."}
}

# Linear upgrades lead to level 3; level 4 requires a specialization.
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

# Ordered left/right specializations. Costs are equal within each tower family.
const BRANCHES := {
	"rapid": {
		"frostneedle": {"name": "Frostneedle", "color": "96d6e6", "cost": 180.0, "description": "Ice needles slow enemies by 25% for 2 seconds. Repeated hits refresh the slow; they never stack."},
		"thorn_volley": {"name": "Thorn Volley", "color": "93b979", "cost": 180.0, "description": "Fires five arrows in a wide fan. Each keeps level-3 damage. The center aims at the target; four fixed-angle outer arrows can hit surrounding enemies, but often miss."}
	},
	"splash": {
		"cinderfield": {"name": "Cinderfield", "color": "f19b57", "cost": 320.0, "description": "Trades 25% of blast damage for burning ground: 3 seconds at one-third of level-3 damage per second. Overlapping fire from this tower refreshes without stacking."},
		"rupture_pyre": {"name": "Rupture Pyre", "color": "e6a16d", "cost": 320.0, "description": "Blasts deal 50% more damage, fire slower, and push enemies back 20 units. Revenants resist 75% of the push. Enemies resist another push for 1 second."}
	},
	"heavy": {
		"grave_echo": {"name": "Grave Echo", "color": "c3a0ed", "cost": 360.0, "description": "A heavy orb bursts into five seeking fragments. Each deals 20% of its damage to a different enemy within 90 units. The original target is excluded; unused fragments fade."},
		"doomstone": {"name": "Doomstone", "color": "c282bb", "cost": 360.0, "description": "Consecutive hits on one enemy increase this tower's damage by 20% per curse stack, up to 100% bonus. Switching targets resets the curse."}
	},
	"electric": {
		"tempest_web": {"name": "Tempest Web", "color": "a9dce9", "cost": 300.0, "description": "Strikes up to five enemies. Each strike arcs to one additional, distinct enemy within 60 units for 50% damage, reaching beyond normal range."},
		"thunderseal": {"name": "Thunderseal", "color": "b3b5f1", "cost": 300.0, "description": "Five hits from this tower detonate a seal for triple-hit bonus damage and a 0.4-second stun. Charges reset; 2-second stun immunity prevents continuous lockdown."}
	}
}

static func valid_branch(kind: String, branch: String) -> bool:
	return BRANCHES.has(kind) and BRANCHES[kind].has(branch)

static func tower_stats(tower: Dictionary, tuning: Dictionary = {}) -> Dictionary:
	return stats(tower.kind, tower.level, tuning, tower.get("branch", ""))

# One schema drives the editor and save validation. Overrides belong to a save,
# never to these shared defaults. All values describe level-one/base stats.
const RIFTS := {
	"ashen_forge": {"name": "Forged Rift", "strength": 25.0},
	"drowned_crypt": {"name": "Drowned Rift", "strength": 15.0},
	"bloodmoon_sanctuary": {"name": "Bloodmoon Rift", "strength": 1.0}
}

static func rift_strength(style: String, tuning: Dictionary = {}) -> float:
	return tuned_value("rifts", style, "strength", tuning) if RIFTS.has(style) else 0.0

static func rift_name(style: String) -> String:
	return RIFTS[style].name if RIFTS.has(style) else "Wild Rift"

static func rift_description(style: String, tuning: Dictionary = {}) -> String:
	var amount := String.num(rift_strength(style, tuning), 2)
	match style:
		"ashen_forge": return "Hardened · +" + amount + "% maximum health."
		"drowned_crypt": return "Restless · +" + amount + "% movement speed."
		"bloodmoon_sanctuary": return "Regeneration · Restores " + amount + "% of maximum health each second."
	return "No effect · Enemies keep their normal stats."

const TUNING_FIELDS := {
	"bosses": {
		"hp": {"label": "Health", "suffix": " HP", "min": 1.0, "max": 100000.0, "step": 1.0},
		"speed": {"label": "Move speed", "suffix": " units/s", "min": 1.0, "max": 250.0, "step": 1.0},
		"payout": {"label": "Gold per defeat", "suffix": " gold", "min": 0.0, "max": 10000.0, "step": 1.0},
		"shield": {"label": "Root shield", "suffix": " HP", "min": 0.0, "max": 10000.0, "step": 1.0},
		"regen_period": {"label": "Defense regrowth interval", "suffix": " s", "min": 0.1, "max": 120.0, "step": 0.1},
		"fire_multiplier": {"label": "Cinderfield shield damage", "suffix": "×", "min": 1.0, "max": 10.0, "step": 0.1},
		"regrowth_suppression": {"label": "Counter-tower regrowth suppression", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"rage_threshold": {"label": "Haste / armor health threshold", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"haste_multiplier": {"label": "Low-health speed", "suffix": "×", "min": 1.0, "max": 5.0, "step": 0.1},
		"armor_reduction": {"label": "High-health damage reduction", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"frost_multiplier": {"label": "Frostneedle damage received", "suffix": "×", "min": 0.0, "max": 10.0, "step": 0.1},
		"quench": {"label": "Frostneedle haste suppression", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"toll_period": {"label": "Escort summon interval", "suffix": " s", "min": 0.1, "max": 120.0, "step": 0.1},
		"escort_count": {"label": "Escorts per toll", "suffix": "", "min": 0.0, "max": 20.0, "step": 1.0, "integer": true},
		"escort_limit": {"label": "Living escort limit", "suffix": "", "min": 0.0, "max": 50.0, "step": 1.0, "integer": true},
		"seal_multiplier": {"label": "Thunderseal detonation damage", "suffix": "× hit damage", "min": 0.0, "max": 15.0, "step": 0.1},
		"toll_delay": {"label": "Thunderseal toll delay", "suffix": " s", "min": 0.0, "max": 60.0, "step": 0.1},
		"wards": {"label": "Protective wards", "suffix": " hits", "min": 0.0, "max": 20.0, "step": 1.0, "integer": true},
		"doom_bypass": {"label": "Doomstone bypasses wards (0 off, 1 on)", "suffix": "", "min": 0.0, "max": 1.0, "step": 1.0, "integer": true},
		"curse_threshold": {"label": "Doomstone stacks to suppress regrowth", "suffix": " stacks", "min": 0.0, "max": 5.0, "step": 1.0, "integer": true}
	},
	"rifts": {
		"strength": {"label": "Effect strength", "suffix": "%", "min": 0.0, "max": 100.0, "step": 0.25}
	},
	"enemies": {
		"hp": {"label": "Health", "suffix": " HP", "min": 1.0, "max": 1000.0, "step": 1.0},
		"speed": {"label": "Move speed", "suffix": " units/s", "min": 1.0, "max": 250.0, "step": 1.0},
		"payout": {"label": "Gold per defeat", "suffix": " gold", "min": 0.0, "max": 250.0, "step": 1.0}
	},
	"towers": {
		"damage": {"label": "Damage per hit", "suffix": "", "min": 0.1, "max": 500.0, "step": 0.1},
		"period": {"label": "Attack interval", "suffix": " s", "min": 0.1, "max": 5.0, "step": 0.01},
		"range": {"label": "Reach", "suffix": " units", "min": 10.0, "max": 600.0, "step": 1.0},
		"cost": {"label": "Build cost", "suffix": " gold", "min": 1.0, "max": 1000.0, "step": 1.0},
		"splash": {"label": "Blast radius", "suffix": " units", "min": 0.0, "max": 300.0, "step": 1.0}
	}
}

static func fields_for(category: String, kind: String) -> Dictionary:
	var result := {}
	for stat in TUNING_FIELDS[category]:
		if definitions(category)[kind].has(stat):
			result[stat] = TUNING_FIELDS[category][stat]
	return result

static func definitions(category: String) -> Dictionary:
	if category == "bosses":
		return BOSSES
	if category == "rifts":
		return RIFTS
	return ENEMIES if category == "enemies" else TOWERS

static func tuned_value(category: String, kind: String, stat: String, tuning: Dictionary = {}) -> float:
	return tuning.get(category, {}).get(kind, {}).get(stat, definitions(category)[kind][stat])

static func definition(category: String, kind: String, tuning: Dictionary = {}) -> Dictionary:
	var result: Dictionary = definitions(category)[kind].duplicate()
	result.merge(tuning.get(category, {}).get(kind, {}), true)
	return result

static func valid_tuning(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for category in value:
		if not TUNING_FIELDS.has(category) or not value[category] is Dictionary:
			return false
		for kind in value[category]:
			if not definitions(category).has(kind) or not value[category][kind] is Dictionary:
				return false
			for stat in value[category][kind]:
				if not fields_for(category, kind).has(stat):
					return false
				var number: Variant = value[category][kind][stat]
				var limits: Dictionary = TUNING_FIELDS[category][stat]
				if not (number is float or number is int):
					return false
				if limits.get("integer", false) and number != floor(number):
					return false
				if not is_finite(number) or number < limits.min or number > limits.max:
					return false
	return true

static func money(value: float) -> String:
	if not is_finite(value):
		return "0"
	var n := maxf(0.0, value)
	if n < 1000.0:
		return str(int(n))
	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi"]
	var tier := int(floor(log(n) / log(1000.0)))
	if tier >= suffixes.size():
		var exponent := int(floor(log(n) / log(10.0)))
		return ("%.2f" % (n / pow(10.0, exponent))) + "e" + str(exponent)
	return ("%.1f" % (n / pow(1000.0, tier))) + suffixes[tier]

static func safe(value: Variant) -> float:
	if not (value is float or value is int):
		return 0.0
	return clampf(float(value), 0.0, MAX_MONEY) if is_finite(float(value)) else 0.0

static func stats(kind: String, level: int, tuning: Dictionary = {}, branch: String = "") -> Dictionary:
	var s := definition("towers", kind, tuning)
	var tier := clampi(level, 1, 3)
	if tier == 1:
		return s
	var upgrade: Dictionary = TOWER_UPGRADES[kind][tier - 2]
	if upgrade.has("targets"):
		s.targets = upgrade.targets
	for field in ["damage", "period", "range", "splash"]:
		var base: float = TOWERS[kind][field]
		# Developer controls still edit the base stats and carry the same tier
		# ratios into upgrades. A custom blast on a single-target tower stays fixed.
		if base > 0.0:
			s[field] = upgrade[field] * (s[field] / base)
	if level >= 4 and valid_branch(kind, branch):
		var specialization: Dictionary = BRANCHES[kind][branch]
		s.name = specialization.name
		s.description = specialization.description
		s.color = specialization.color
		match branch:
			"cinderfield": s.damage *= 0.75
			"rupture_pyre":
				s.damage *= 1.5
				s.period *= 1.5 / 1.1
			"grave_echo": s.damage *= 110.0 / 90.0
	s.period = maxf(0.1, s.period)
	return s

static func upgrade_cost(tower: Dictionary, tuning: Dictionary = {}) -> float:
	var level := int(tower.level)
	if level < 1 or level >= MAX_TOWER_LEVEL:
		return 0.0
	var base_cost: float = TOWERS[tower.kind].cost
	var price: float = BRANCHES[tower.kind].values()[0].cost if level == 3 else TOWER_UPGRADES[tower.kind][level - 1].cost
	return ceil(price * (tuned_value("towers", tower.kind, "cost", tuning) / base_cost))

static func invested_cost(tower: Dictionary, tuning: Dictionary = {}) -> float:
	var invested := tuned_value("towers", tower.kind, "cost", tuning)
	for level in range(1, clampi(int(tower.level), 1, MAX_TOWER_LEVEL)):
		invested = minf(MAX_MONEY, invested + upgrade_cost({"kind": tower.kind, "level": level}, tuning))
	return invested

static func sell_refund(tower: Dictionary, tuning: Dictionary = {}) -> float:
	return floor(invested_cost(tower, tuning) * SELL_REFUND_RATIO)

static func move_cost(tower: Dictionary, tuning: Dictionary = {}) -> float:
	return ceil(invested_cost(tower, tuning) * MOVE_COST_RATIO)

static func rebuild_seconds(tower: Dictionary, tuning: Dictionary = {}) -> float:
	return clampf(ceil(tuned_value("towers", tower.kind, "cost", tuning) * 0.5 + (tower.level - 1) * REBUILD_SECONDS_PER_LEVEL), 1.0, MAX_REBUILD_SECONDS)

static func rebuild_time_text(seconds: float) -> String:
	var whole := ceili(maxf(0.0, seconds))
	return "%d:%02d" % [whole / 60, whole % 60]

static func expansion_cost(count: int) -> float:
	return ceil(100.0 * pow(float(count), 1.35))

static func traffic_period(level: int) -> float:
	return BASE_SPAWN_PERIOD / (1.0 + level * TRAFFIC_INCREMENT)

static func enemy_mix(unlocks: Array) -> Dictionary:
	var mix := {}
	var remaining := 1.0
	for kind in ENEMY_SHARES:
		if kind in unlocks:
			mix[kind] = ENEMY_SHARES[kind]
			remaining -= ENEMY_SHARES[kind]
	mix["basic"] = maxf(0.0, remaining)
	return mix

static func enemy_kind(unlocks: Array, roll: float) -> String:
	var cumulative := 0.0
	var mix := enemy_mix(unlocks)
	for kind in mix:
		cumulative += mix[kind]
		if roll < cumulative:
			return kind
	return "basic"
