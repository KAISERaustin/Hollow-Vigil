class_name Balance
extends RefCounted

const VERSION := 1
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
const MAX_TOWER_LEVEL := 10000
const TRAFFIC_BASE_COST := 80.0
const TRAFFIC_COST_GROWTH := 1.8
const AUTOMATION_COST := 600.0
const SELL_REFUND_RATIO := 0.5
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

static func stats(kind: String, level: int) -> Dictionary:
	var s: Dictionary = TOWERS[kind].duplicate()
	var l := clampi(level, 1, MAX_TOWER_LEVEL) - 1
	s.damage *= 1.0 + l * 0.45
	s.period = maxf(0.1, s.period / (1.0 + l * 0.12))
	s.range += minf(65.0, l * 7.0)
	if s.splash > 0.0:
		s.splash += minf(55.0, l * 4.0)
	return s

static func upgrade_cost(tower: Dictionary) -> float:
	return ceil(minf(MAX_MONEY, TOWERS[tower.kind].cost * 0.7 * pow(1.55, mini(tower.level - 1, 700))))

static func sell_refund(tower: Dictionary) -> float:
	var invested: float = TOWERS[tower.kind].cost
	for level in range(1, int(tower.level)):
		invested = minf(MAX_MONEY, invested + upgrade_cost({"kind": tower.kind, "level": level}))
	return floor(invested * SELL_REFUND_RATIO)

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
