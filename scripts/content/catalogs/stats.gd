extends RefCounted

const Frozen = preload("res://scripts/content/catalogs/stats_defaults.gd")
const Tuning = preload("res://scripts/content/catalogs/tuning.gd")
const Capabilities = preload("res://scripts/content/catalogs/stat_capabilities.gd")
const Gear = preload("res://scripts/content/catalogs/gear.gd")
const Actors = preload("res://scripts/content/catalogs/actors.gd")
const Towers = preload("res://scripts/content/catalogs/towers.gd")
const CATEGORIES := ["towers", "enemies", "bosses"]
const REQUIRED := ["hp", "speed", "cost", "period", "range", "damage", "targets", "escape_damage", "projectile_speed"]
static var schemas := {}
static var libraries := {}
static var extensions := {}

static func capabilities(category: String) -> Dictionary:
	if libraries.has(category): return libraries[category]
	var result: Dictionary = (Capabilities.TOWER if category == "towers" else Capabilities.ENEMY).duplicate(true)
	if category == "towers":
		for kind in Gear.GEAR:
			var fields := {}
			for field in Gear.GEAR[kind]:
				if field == "name" or field in Tuning.RETIRED_FIELDS.gear.get(kind, []): continue
				fields["gear_" + kind + "__" + field] = Gear.GEAR[kind][field]
			result["gear_" + kind] = {"name": Gear.GEAR[kind].name + " effect", "group": "Attributes", "fields": fields}
	libraries[category] = result
	return result

static func control(field: String) -> bool:
	return field.begins_with("use_") or field.begins_with("enabled_")

static func schema(category: String) -> Dictionary:
	if schemas.has(category): return schemas[category]
	var result: Dictionary = Tuning.TUNING_FIELDS[category].duplicate(true)
	if category == "towers":
		result.projectile_speed = {"label": "Projectile speed", "suffix": " units/s", "min": 1.0, "max": 10000.0, "step": 1.0}
	else:
		result.merge(Tuning.TUNING_FIELDS.bosses.duplicate(true), true)
		result.escape_damage = {"label": "Core damage on escape", "suffix": "", "min": 0.0, "max": 10000.0, "step": 1.0, "integer": true}
		for field in Capabilities.RESISTANCES:
			result[field] = {"label": Capabilities.RESISTANCES[field], "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0, "group": "Attributes"}
	for ability in capabilities(category):
		for field in capabilities(category)[ability].fields:
			if field.begins_with("gear_"):
				var original: String = field.get_slice("__", 1)
				result[field] = Tuning.TUNING_FIELDS.gear[original].duplicate(true)
				result[field].label = capabilities(category)[ability].name + " · " + result[field].label
			result[field]["requires"] = ability if not result[field].has("requires") else result[field].requires
		result["use_" + ability] = {"label": capabilities(category)[ability].name, "suffix": "", "min": 0.0, "max": 1.0, "step": 1.0, "integer": true}
	for field in result.keys():
		if control(field): continue
		result["enabled_" + field] = {"label": result[field].label, "suffix": "", "min": 0.0, "max": 1.0, "step": 1.0, "integer": true}
	schemas[category] = result
	return result

static func baseline(category: String, kind: String) -> Dictionary:
	if extensions.get(category, {}).has(kind): return extensions[category][kind].duplicate(true)
	var result: Dictionary = Frozen.VALUES[category][kind].duplicate(true)
	if category == "towers": result.projectile_speed = Towers.PROJECTILES[kind.get_slice(":", 0)].speed
	else: result.escape_damage = 20 if category == "bosses" else Actors.ENEMY_RULES.get(kind, {}).get("escape_damage", 1)
	return result

static func register_baseline(category: String, kind: String, values: Dictionary) -> void:
	if category not in CATEGORIES or Frozen.VALUES[category].has(kind): return
	if not extensions.has(category): extensions[category] = {}
	var stats := {}
	for field in values:
		if schema(category).has(field) and not control(field): stats[field] = values[field]
	extensions[category][kind] = stats

static func ability_enabled(category: String, kind: String, ability: String, tuning: Dictionary) -> bool:
	return tuning.get(category, {}).get(kind, {}).get("use_" + ability, 1 if ability in Capabilities.defaults(category, kind) else 0) > 0

static func default_value(category: String, kind: String, field: String) -> float:
	if field.begins_with("use_"): return 1.0 if field.trim_prefix("use_") in Capabilities.defaults(category, kind) else 0.0
	if field.begins_with("enabled_"): return 1.0 if baseline(category, kind).has(field.trim_prefix("enabled_")) else 0.0
	var values := baseline(category, kind)
	if values.has(field): return float(values[field])
	for ability in capabilities(category).values():
		if ability.fields.has(field): return float(ability.fields[field])
	if field == "arrow_count": return 5.0
	return 0.0

static func enabled(category: String, kind: String, field: String, tuning: Dictionary) -> bool:
	return tuning.get(category, {}).get(kind, {}).get("enabled_" + field, 1 if baseline(category, kind).has(field) or tuning.get(category, {}).get(kind, {}).has(field) else 0) > 0

static func value(category: String, kind: String, field: String, tuning: Dictionary) -> float:
	return float(tuning.get(category, {}).get(kind, {}).get(field, default_value(category, kind, field)))

static func resolve(category: String, kind: String, identity: Dictionary, tuning: Dictionary) -> Dictionary:
	var result := identity.duplicate(true)
	var values := baseline(category, kind)
	for ability in capabilities(category):
		if ability_enabled(category, kind, ability, tuning):
			for field in capabilities(category)[ability].fields:
				if not values.has(field): values[field] = capabilities(category)[ability].fields[field]
	var edits: Dictionary = tuning.get(category, {}).get(kind, {})
	values.merge(edits, true)
	for field in values:
		if control(field): continue
		result[field] = values[field] if edits.get("enabled_" + field, 1) > 0 else neutral(field)
	if edits.keys().any(func(field): return str(field).begins_with("use_")):
		var names: PackedStringArray = []
		for ability in capabilities(category):
			if ability_enabled(category, kind, ability, tuning): names.append(capabilities(category)[ability].name)
		result.description = "Assigned capabilities: " + ", ".join(names) + "." if not names.is_empty() else ("Standard shots with this tier's configured stats." if category == "towers" else "Uses its configured stats without additional abilities.")
	return result

static func neutral(field: String) -> float:
	return 1.0 if field in ["boss_damage_multiplier", "pierce_floor", "return_speed", "haste_multiplier", "fire_multiplier", "frost_multiplier", "seal_multiplier"] else 0.0

static func edit(tuning: Dictionary, category: String, kind: String, field: String, number: float) -> Dictionary:
	var result := tuning.duplicate(true)
	if not result.has(category): result[category] = {}
	if not result[category].has(kind): result[category][kind] = {}
	result[category][kind][field] = number
	return result

static func attach(tuning: Dictionary, category: String, kind: String, ability: String, active: bool = true) -> Dictionary:
	var result := edit(tuning, category, kind, "use_" + ability, 1 if active else 0)
	var capability: Dictionary = capabilities(category)[ability]
	if active:
		if capability.get("primary", false):
			for other in capabilities(category):
				if other != ability and capabilities(category)[other].get("primary", false): result[category][kind]["use_" + other] = 0
		for field in capability.fields:
			result[category][kind]["enabled_" + field] = 1
			if not result[category][kind].has(field): result[category][kind][field] = default_value(category, kind, field)
	return result

static func reset(tuning: Dictionary, category: String, kind: String) -> Dictionary:
	var result := tuning.duplicate(true)
	if not result.has(category): result[category] = {}
	result[category][kind] = {}
	for field in schema(category): result[category][kind][field] = default_value(category, kind, field)
	return result

static func compact(tuning: Dictionary) -> Dictionary:
	var result := tuning.duplicate(true)
	for category in CATEGORIES:
		if not result.has(category): continue
		for kind in result[category].keys():
			var values: Dictionary = result[category][kind]
			for field in values.keys():
				if control(field): continue
				# Explicitly added neutral stats still need their enabled marker.
				if not baseline(category, kind).has(field) and not values.has("enabled_" + field):
					values["enabled_" + field] = 1
				if is_equal_approx(float(values[field]), default_value(category, kind, field)): values.erase(field)
			for field in values.keys():
				if not control(field): continue
				if field.begins_with("enabled_") and values[field] == 0 and values.has(field.trim_prefix("enabled_")): continue
				if is_equal_approx(float(values[field]), default_value(category, kind, field)): values.erase(field)
			if values.is_empty(): result[category].erase(kind)
		if result[category].is_empty(): result.erase(category)
	return result
