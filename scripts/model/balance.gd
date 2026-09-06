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
const BASE_SPAWN_PERIOD := 1.7
const TRAFFIC_INCREMENT := 0.25
const MAX_TRAFFIC_LEVEL := 12
const MAX_TOWER_LEVEL := 3
const TRAFFIC_BASE_COST := 80.0
const TRAFFIC_COST_GROWTH := 1.8
const AUTOMATION_COST := 600.0
const SELL_REFUND_RATIO := 0.5
const MOVE_COST_RATIO := 0.2
const MAX_REBUILD_SECONDS := 180.0
const REBUILD_SECONDS_PER_LEVEL := 15.0
const MIN_PRODUCTION_SAMPLE := 60.0
const UNLOCK_COSTS := {"fast": 90.0, "heavy": 180.0}
const ENEMY_SHARES := {"fast": 0.30, "heavy": 0.18}
const ENEMIES := {
	"basic": {"name": "Hollow", "role": "COMMON", "description": "A steady traveler from every rift. Low health makes it easy prey for your sentinels.", "hp": 15.0, "speed": 39.0, "payout": 5.0, "color": "e8ddbd"},
	"fast": {"name": "Wraith", "role": "FAST", "description": "A fragile, swift spirit. Its speed gives your towers less time to strike before it reaches the core.", "hp": 12.0, "speed": 74.0, "payout": 8.0, "color": "93c9bc"},
	"heavy": {"name": "Revenant", "role": "DURABLE", "description": "A slow, resilient foe with a rich bounty. High-damage towers help cut through its large health pool.", "hp": 85.0, "speed": 25.0, "payout": 24.0, "color": "db8d73"}
}
const TOWERS := {
	"rapid": {"name": "Ashneedle", "role": "RAPID", "cost": 60.0, "damage": 6.0, "period": 0.48, "range": 132.0, "splash": 0.0, "color": "e0b568", "description": "Swift pointed darts cut through hollows and wraiths."},
	"splash": {"name": "Pyre", "role": "SPLASH", "cost": 120.0, "damage": 15.0, "period": 1.5, "range": 126.0, "splash": 46.0, "color": "db8d73", "description": "Flame waves burst on impact, striking every enemy within the blast radius."},
	"heavy": {"name": "Obelisk", "role": "HEAVY", "cost": 160.0, "damage": 40.0, "period": 1.8, "range": 157.0, "splash": 0.0, "color": "b49dcc", "description": "Large magic orbs reach distant foes and deal heavy damage to resilient enemies."}
}

# Each row buys the next level (1 -> 2, then 2 -> 3). Fixed tiers preserve
# distinct combat roles; there is no extrapolated fourth level or price.
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
	]
}

# One schema drives the editor and save validation. Overrides belong to a save,
# never to these shared defaults. All values describe level-one/base stats.
const TUNING_FIELDS := {
	"enemies": {
		"hp": {"label": "Health", "suffix": " HP", "min": 1.0, "max": 1000.0, "step": 1.0},
		"speed": {"label": "Move speed", "suffix": " units/s", "min": 1.0, "max": 250.0, "step": 1.0},
		"payout": {"label": "Defeat reward", "suffix": " gold", "min": 0.0, "max": 250.0, "step": 1.0}
	},
	"towers": {
		"damage": {"label": "Damage per hit", "suffix": "", "min": 0.1, "max": 500.0, "step": 0.1},
		"period": {"label": "Attack interval", "suffix": " s", "min": 0.1, "max": 5.0, "step": 0.01},
		"range": {"label": "Reach", "suffix": " units", "min": 10.0, "max": 600.0, "step": 1.0},
		"cost": {"label": "Build cost", "suffix": " gold", "min": 1.0, "max": 1000.0, "step": 1.0},
		"splash": {"label": "Blast radius", "suffix": " units", "min": 0.0, "max": 300.0, "step": 1.0}
	}
}

static func definitions(category: String) -> Dictionary:
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
				if not TUNING_FIELDS[category].has(stat):
					return false
				var number: Variant = value[category][kind][stat]
				var limits: Dictionary = TUNING_FIELDS[category][stat]
				if not (number is float or number is int):
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

static func stats(kind: String, level: int, tuning: Dictionary = {}) -> Dictionary:
	var s := definition("towers", kind, tuning)
	var tier := clampi(level, 1, MAX_TOWER_LEVEL)
	if tier == 1:
		return s
	var upgrade: Dictionary = TOWER_UPGRADES[kind][tier - 2]
	for field in ["damage", "period", "range", "splash"]:
		var base: float = TOWERS[kind][field]
		# Developer controls still edit the base stats and carry the same tier
		# ratios into upgrades. A custom blast on a single-target tower stays fixed.
		if base > 0.0:
			s[field] = upgrade[field] * (s[field] / base)
	s.period = maxf(0.1, s.period)
	return s

static func upgrade_cost(tower: Dictionary, tuning: Dictionary = {}) -> float:
	var level := int(tower.level)
	if level < 1 or level >= MAX_TOWER_LEVEL:
		return 0.0
	var base_cost: float = TOWERS[tower.kind].cost
	return ceil(TOWER_UPGRADES[tower.kind][level - 1].cost * (tuned_value("towers", tower.kind, "cost", tuning) / base_cost))

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
