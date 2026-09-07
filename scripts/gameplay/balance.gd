class_name Balance
extends RefCounted

const Content = preload("res://scripts/content/registry.gd")

const VERSION := 2
const TARGET_MODES := {"first": "First", "last": "Last", "most_hp": "Most HP"}
const TILE := 300.0
const MAX_MONEY := 1.0e150
const STEP := 0.05
const HISTORY_SECONDS := 180.0
const OFFLINE_FACTOR := 0.8
const MAX_OFFLINE_SECONDS := 604800.0 # Seven-day guard against large forward clock jumps.
const STARTING_GOLD = preload("res://scripts/content/catalogs/levels.gd").STARTING_GOLD
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
const UNLOCK_COSTS = preload("res://scripts/content/catalogs/actors.gd").UNLOCK_COSTS

const ENEMY_SHARES = preload("res://scripts/content/catalogs/actors.gd").ENEMY_SHARES

const NORMAL_KINDS = preload("res://scripts/content/catalogs/actors.gd").NORMAL_KINDS

const DUNGEON_KINDS = preload("res://scripts/content/catalogs/actors.gd").DUNGEON_KINDS

const ORCHARD_KINDS = preload("res://scripts/content/catalogs/actors.gd").ORCHARD_KINDS
const CAMPAIGN_KINDS = preload("res://scripts/content/catalogs/actors.gd").CAMPAIGN_KINDS

# Stable numeric escort choices intentionally exclude portal-exclusive orchard foes.
const ESCORT_KINDS = preload("res://scripts/content/catalogs/actors.gd").ESCORT_KINDS

const ENEMIES = preload("res://scripts/content/catalogs/actors.gd").ENEMIES

const BOSSES = preload("res://scripts/content/catalogs/actors.gd").BOSSES

const TOWERS = preload("res://scripts/content/catalogs/towers.gd").TOWERS

# Shared by ordinary projectiles, branch volleys and cosmetic shot records.
const PROJECTILES = preload("res://scripts/content/catalogs/towers.gd").PROJECTILES

# Linear upgrades lead to level 3; level 4 requires a specialization.
const TOWER_UPGRADES = preload("res://scripts/content/catalogs/towers.gd").TOWER_UPGRADES

# Ordered left/right specializations. Costs are equal within each tower family.
const BRANCHES = preload("res://scripts/content/catalogs/towers.gd").BRANCHES

const BRANCH_STAT_MULTIPLIERS = preload("res://scripts/content/catalogs/towers.gd").BRANCH_STAT_MULTIPLIERS

const ABILITIES = preload("res://scripts/content/catalogs/towers.gd").ABILITIES

static func valid_branch(kind: String, branch: String) -> bool:
	var node := Content.tower(kind)
	return node != null and node.valid_branch(branch)

static func tower_stats(tower: Dictionary, tuning: Dictionary = {}, inventory: Dictionary = {}) -> Dictionary:
	var result := stats(tower.kind, tower.level, tuning, tower.get("branch", ""))
	return equipment_stats(result, tower, tuning, inventory)

static func equipment_stats(base: Dictionary, tower: Dictionary, tuning: Dictionary, inventory: Dictionary) -> Dictionary:
	var gear := Content.gear(inventory.get(tower.get("relic", ""), ""))
	return gear.modify_stats(base, tuning) if gear != null else base

# One schema drives the editor and save validation. Overrides belong to a save,
# never to these shared defaults. Tower keys may identify a tier or branch.
const RIFTS = preload("res://scripts/content/catalogs/world.gd").RIFTS

static func rift_strength(style: String, tuning: Dictionary = {}) -> float:
	return tuned_value("rifts", style, "strength", tuning) if RIFTS.has(style) else 0.0

static func portal_kinds(style: String) -> Array:
	var node := Content.portal(style)
	return node.enemy_kinds() if node != null else NORMAL_KINDS.duplicate()

static func exclusive_portal(style: String) -> bool:
	var node := Content.portal(style)
	return node != null and node.is_exclusive()

static func portal_unlock_costs(style: String) -> Dictionary:
	var node := Content.portal(style)
	return node.unlock_costs() if node != null else UNLOCK_COSTS.duplicate()

static func portal_available_kinds(style: String, unlocks: Array) -> Array:
	var node := Content.portal(style)
	return node.available_kinds(unlocks) if node != null else NORMAL_KINDS.duplicate()

static func rift_name(style: String) -> String:
	var node := Content.portal(style)
	return node.attribute("name") if node != null else "Wild Rift"

static func rift_description(style: String, tuning: Dictionary = {}) -> String:
	var portal := Content.portal(style)
	if portal == null:
		return ""
	var inhabitants: Array[String] = []
	for kind in portal.enemy_kinds():
		inhabitants.append(ENEMIES[kind].name)
	var roster := "Summons only " + ", ".join(inhabitants) + ". "
	var availability := "All three are active immediately, with equal chances." if portal.unlock_costs().is_empty() else "Attune the other inhabitants to add them to this portal's spawns."
	var amount := String.num(rift_strength(style, tuning), 2)
	match style:
		"mourning_orchard":
			return roster + availability
		"castle_ruin": return "One dungeon portal per castle ruin. " + roster + availability
		"ashen_forge": return roster + availability + " Hardened: +" + amount + "% maximum health throughout the journey."
		"drowned_crypt": return roster + availability + " Restless: +" + amount + "% movement speed throughout the journey."
		"bloodmoon_sanctuary": return roster + availability + " Regeneration: restores " + amount + "% of maximum health each second throughout the journey."
	return roster + availability

static func enemy_portal_style(kind: String) -> String:
	var node := Content.enemy(kind)
	return node.rule("portal_style", "forest") if node != null else "forest"

const GEAR = preload("res://scripts/content/catalogs/gear.gd").GEAR

const TUNING_FIELDS = preload("res://scripts/content/catalogs/tuning.gd").TUNING_FIELDS

static func fields_for(category: String, kind: String) -> Dictionary:
	var result := {}
	var order: Array = ["hp", "speed", "payout", "cost", "damage", "period", "range", "splash", "targets"]
	for stat in TUNING_FIELDS[category]:
		if stat not in order:
			order.append(stat)
	for stat in order:
		if TUNING_FIELDS[category].has(stat) and definitions(category)[kind].has(stat):
			result[stat] = field_limits(category, kind, stat)
	return result

static func editable_fields_for(category: String, kind: String) -> Dictionary:
	var result := fields_for(category, kind)
	var retired: Dictionary = preload("res://scripts/content/catalogs/tuning.gd").RETIRED_FIELDS
	for stat in retired.get(category, {}).get(kind, []):
		result.erase(stat)
	return result

# Legacy base tuning scales some upgrades beyond the base slider's ceiling.
# Those inherited values must remain representable as independent tier values.
static func field_limits(category: String, kind: String, stat: String) -> Dictionary:
	var limits: Dictionary = TUNING_FIELDS[category][stat].duplicate()
	if category == "towers" and kind.contains(":") and stat in ["cost", "damage", "range", "splash"]:
		var base: float = TOWERS[kind.get_slice(":", 0)][stat]
		if base > 0.0:
			limits.max = ceil(limits.max * maxf(1.0, definitions(category)[kind][stat] / base)) + 1.0 # Allow scaling roundoff.
	return limits

static func definitions(category: String) -> Dictionary:
	return Content.catalog().definitions(category)

static func tier_key(kind: String, level: int, branch: String = "") -> String:
	return kind if level == 1 else kind + ":" + (branch if level == 4 else str(level))

static func tower_definitions() -> Dictionary:
	return definitions("towers")

static func tuned_value(category: String, kind: String, stat: String, tuning: Dictionary = {}) -> float:
	var node := Content.catalog().find(category, kind)
	return tuning.get(category, {}).get(kind, {}).get(stat, node.attribute(stat))

static func definition(category: String, kind: String, tuning: Dictionary = {}) -> Dictionary:
	var node := Content.catalog().find(category, kind)
	if node == null:
		return {}
	var result := node.definition(tuning)
	if category == "towers":
		result.description = tower_description(result)
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
				var limits: Dictionary = field_limits(category, kind, stat)
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

static func _scaled_stats(kind: String, level: int, tuning: Dictionary = {}, branch: String = "") -> Dictionary:
	return Content.tower(kind).scaled_stats(level, tuning, branch)

static func stats(kind: String, level: int, tuning: Dictionary = {}, branch: String = "") -> Dictionary:
	return Content.tower(kind).stats(level, tuning, branch)

# Descriptions use the same resolved values as combat, including tier overrides.
static func tower_description(resolved: Dictionary) -> String:
	var values := {}
	for field in resolved:
		if resolved[field] is float or resolved[field] is int:
			values[field] = String.num(float(resolved[field]), 2)
	values.poison_dps = String.num(resolved.damage * resolved.get("dot_multiplier", 0.0), 2)
	values.burn_dps = String.num(resolved.damage * resolved.get("burn_multiplier", 0.0), 2)
	for prefix in ["fragment", "curse", "arc"]:
		values[prefix + "_percent"] = String.num(resolved.get(prefix + "_multiplier", 0.0) * 100.0, 2)
	values.curse_max_percent = String.num(resolved.get("curse_multiplier", 0.0) * resolved.get("curse_limit", 0) * 100.0, 2)
	for field in values:
		values[field] = values[field].trim_suffix(".0")
	return resolved.description.format(values)

static func upgrade_cost(tower: Dictionary, tuning: Dictionary = {}, branch: String = "") -> float:
	var level := int(tower.level)
	if level < 1 or level >= MAX_TOWER_LEVEL:
		return 0.0
	var selected: String = branch if branch != "" else tower.get("branch", "")
	if level == 3 and not valid_branch(tower.kind, selected):
		selected = BRANCHES[tower.kind].keys()[0]
	var key := tier_key(tower.kind, level + 1, selected)
	if tuning.get("towers", {}).get(key, {}).has("cost"):
		return tuning.towers[key].cost
	var price: float = tower_definitions()[key].cost
	return ceil(price * (tuned_value("towers", tower.kind, "cost", tuning) / TOWERS[tower.kind].cost))

static func invested_cost(tower: Dictionary, tuning: Dictionary = {}) -> float:
	var invested := tuned_value("towers", tower.kind, "cost", tuning)
	for level in range(1, clampi(int(tower.level), 1, MAX_TOWER_LEVEL)):
		invested = minf(MAX_MONEY, invested + upgrade_cost({"kind": tower.kind, "level": level, "branch": tower.get("branch", BRANCHES[tower.kind].keys()[0])}, tuning))
	return invested

static func sell_refund(tower: Dictionary, tuning: Dictionary = {}) -> float:
	return floor(invested_cost(tower, tuning) * SELL_REFUND_RATIO)

static func move_cost(tower: Dictionary, tuning: Dictionary = {}) -> float:
	return ceil(invested_cost(tower, tuning) * MOVE_COST_RATIO)

static func rebuild_seconds(tower: Dictionary, tuning: Dictionary = {}) -> float:
	return clampf(ceil(tuned_value("towers", tower.kind, "cost", tuning) * 0.5 + (tower.level - 1) * REBUILD_SECONDS_PER_LEVEL), 1.0, MAX_REBUILD_SECONDS)

static func rebuild_time_text(seconds: float) -> String:
	var whole := ceili(maxf(0.0, seconds))
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]

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

static func merge_tuning(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for category in overrides:
		if not result.has(category): result[category] = {}
		for kind in overrides[category]:
			if not result[category].has(kind): result[category][kind] = {}
			result[category][kind].merge(overrides[category][kind], true)
	return result

# Editor, override comparison and exports share the same resolved tier values.
static func configuration_value(category: String, kind: String, stat: String, tuning: Dictionary = {}) -> float:
	if category != "towers": return tuned_value(category, kind, stat, tuning)
	var node := Content.catalog().find("towers", kind)
	var base: String = node.rule("base_kind", kind)
	var level: int = node.rule("level", 1)
	var branch: String = node.rule("branch", "")
	if stat == "cost":
		return upgrade_cost({"kind": base, "level": level - 1}, tuning, branch) if level > 1 else tuned_value(category, kind, stat, tuning)
	return stats(base, level, tuning, branch)[stat]

static func rift_health_multiplier(style: String, tuning: Dictionary = {}) -> float:
	return 1.0 + rift_strength(style, tuning) / 100.0 if style == "ashen_forge" else 1.0

static func rift_speed_multiplier(style: String, tuning: Dictionary = {}) -> float:
	return 1.0 + rift_strength(style, tuning) / 100.0 if style == "drowned_crypt" else 1.0
