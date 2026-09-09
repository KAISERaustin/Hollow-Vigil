class_name Balance
extends RefCounted

const Content = preload("res://scripts/content/registry.gd")
const Stats = preload("res://scripts/content/catalogs/stats.gd")

const VERSION := 2
const TARGET_MODES := {"first": "First", "last": "Last", "most_hp": "Most HP"}
const TILE := 300.0
const MAX_MONEY := 1.0e150
const STEP := 0.05
const STARTING_GOLD = preload("res://scripts/content/catalogs/levels.gd").STARTING_GOLD
const MAX_TRAFFIC_LEVEL := 12
const MAX_TOWER_LEVEL := 4
const SELL_REFUND_RATIO := 0.5
const MOVE_COST_RATIO := 0.2
const MAX_REBUILD_SECONDS := 180.0
const REBUILD_SECONDS_PER_LEVEL := 15.0


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
	var result := base
	var equipped: String = inventory.get(tower.get("relic", ""), "")
	var key := tier_key(tower.kind, tower.level, tower.get("branch", ""))
	if gear != null and not Stats.ability_enabled("towers", key, "gear_" + equipped, tuning): result = gear.modify_stats(result, tuning)
	for assignment in preload("res://scripts/gameplay/combat/stat_composition.gd").direct_gear(tower, tuning, inventory): result = assignment.node.modify_stats(result)
	return result

# One schema drives the editor and save validation. Overrides belong to a save,
# never to these shared defaults. Tower keys may identify a tier or branch.
const RIFTS = preload("res://scripts/content/catalogs/world.gd").RIFTS

static func rift_strength(style: String, tuning: Dictionary = {}) -> float:
	return tuned_value("rifts", style, "strength", tuning) if RIFTS.has(style) else 0.0

static func portal_kinds(style: String) -> Array:
	var node := Content.portal(style)
	return node.enemy_kinds() if node != null else NORMAL_KINDS.duplicate()

static func rift_name(style: String) -> String:
	var node := Content.portal(style)
	return node.attribute("name") if node != null else "Wild Rift"

static func portal_definitions() -> Dictionary:
	# All portal identities are discoverable, including types without tunable effects.
	var result := {}
	for node in Content.catalog().children("portal"):
		result[node.rule("kind")] = node.attributes()
	return result

static func rift_description(style: String, tuning: Dictionary = {}, _authored_spawns: bool = true) -> String:
	if Content.portal(style) == null: return ""
	var effect := portal_effect_description(style, tuning)
	return "Used at every campaign entrance in this biome. Enemies and timing follow the authored waves. " + (effect if not effect.is_empty() else "No additional portal effect.")

static func portal_effect_description(style: String, tuning: Dictionary = {}) -> String:
	var amount := String.num(rift_strength(style, tuning), 2)
	match style:
		"ashen_forge": return "Hardened: +" + amount + "% maximum health throughout the journey."
		"drowned_crypt": return "Restless: +" + amount + "% movement speed throughout the journey."
		"bloodmoon_sanctuary": return "Regeneration: restores " + amount + "% of maximum health each second throughout the journey."
	return ""

static func enemy_portal_style(kind: String) -> String:
	var node := Content.enemy(kind)
	return node.rule("portal_style", "forest") if node != null else "forest"

const GEAR = preload("res://scripts/content/catalogs/gear.gd").GEAR

const TUNING_FIELDS = preload("res://scripts/content/catalogs/tuning.gd").TUNING_FIELDS

static func fields_for(category: String, kind: String) -> Dictionary:
	if category in Stats.CATEGORIES:
		var fields := {}
		var base := Stats.baseline(category, kind)
		var order: Array = ["hp", "speed", "payout", "cost", "damage", "period", "range", "splash", "targets"]
		for field in base:
			if field not in order: order.append(field)
		for field in order:
			if base.has(field): fields[field] = field_limits(category, kind, field)
		return fields
	var result := {}
	var schema: Dictionary = TUNING_FIELDS[category]
	var defaults: Dictionary = definitions(category)[kind]
	var order: Array = ["hp", "speed", "payout", "cost", "damage", "period", "range", "splash", "targets"]
	for stat in schema:
		if stat not in order:
			order.append(stat)
	for stat in order:
		if schema.has(stat) and defaults.has(stat):
			result[stat] = _resolved_field_limits(category, kind, stat, defaults)
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
	return _resolved_field_limits(category, kind, stat)

static func _resolved_field_limits(category: String, kind: String, stat: String, defaults: Dictionary = {}) -> Dictionary:
	var limits: Dictionary = (Stats.schema(category) if category in Stats.CATEGORIES else TUNING_FIELDS[category])[stat].duplicate()
	if category == "towers" and kind.contains(":") and stat in ["cost", "damage", "range", "splash"]:
		var base: float = TOWERS[kind.get_slice(":", 0)][stat]
		if base > 0.0:
			if defaults.is_empty(): defaults = definitions(category)[kind]
			limits.max = ceil(limits.max * maxf(1.0, defaults[stat] / base)) + 1.0 # Allow scaling roundoff.
	return limits

static func definitions(category: String) -> Dictionary:
	return Content.catalog().definitions(category)

static func tier_key(kind: String, level: int, branch: String = "") -> String:
	return kind if level == 1 else kind + ":" + (branch if level == 4 else str(level))

static func tower_definitions() -> Dictionary:
	return definitions("towers")

static func tuned_value(category: String, kind: String, stat: String, tuning: Dictionary = {}) -> float:
	if category in Stats.CATEGORIES:
		if Stats.control(stat): return Stats.value(category, kind, stat, tuning)
		return float(definition(category, kind, tuning).get(stat, Stats.default_value(category, kind, stat)))
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
		# Resolve this call's catalog once; later calls still see newly registered
		# nodes. Validation only needs membership and limits, not editor ordering.
		var schema: Dictionary = Stats.schema(category) if category in Stats.CATEGORIES else TUNING_FIELDS[category]
		var catalog: Dictionary = definitions(category)
		for kind in value[category]:
			if not catalog.has(kind) or not value[category][kind] is Dictionary:
				return false
			var defaults: Dictionary = catalog[kind]
			if category == "towers":
				var primary_count := 0
				for ability in Stats.Capabilities.TOWER:
					if Stats.Capabilities.TOWER[ability].get("primary", false) and Stats.ability_enabled(category, kind, ability, value): primary_count += 1
				if primary_count > 1: return false
			for stat in value[category][kind]:
				if not schema.has(stat) or (category not in Stats.CATEGORIES and not defaults.has(stat)):
					return false
				if category in Stats.CATEGORIES and stat.begins_with("enabled_") and stat.trim_prefix("enabled_") in Stats.REQUIRED and value[category][kind][stat] != 1: return false
				var number: Variant = value[category][kind][stat]
				var limits := _resolved_field_limits(category, kind, stat, defaults)
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
	return Stats.default_value("towers", key, "cost")

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
	if category in Stats.CATEGORIES: return Stats.value(category, kind, stat, tuning)
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
