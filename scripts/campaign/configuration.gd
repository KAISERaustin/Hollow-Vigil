extends VigilSaveStore
## Campaign authoring data is independent of account and completion saves.
const Catalog = preload("res://scripts/campaign/catalog.gd")
const Fields = preload("res://scripts/content/catalogs/levels.gd")
const FORMAT := "hollow-vigil-campaign-level-v1"
var path := "user://vigil-campaign-configuration.save"
var data := {"version": 1, "sequence": 0, "levels": {}}
var blocked := false

func valid_data(value: Dictionary) -> bool:
	if value.size() != 3 or value.get("version") != 1 or not _number(value.get("sequence"), 0, 1e15, true) or not value.get("levels") is Dictionary: return false
	for key in value.levels:
		if not key is String or not key.is_valid_int() or str(int(key)) != key or int(key) < 0 or int(key) >= Catalog.COUNT or not valid_level(int(key), value.levels[key]): return false
	return true

static func valid_level(index: int, value: Variant) -> bool:
	if index < 0 or index >= Catalog.COUNT or not value is Dictionary: return false
	var mission := Catalog.level(index)
	for key in value:
		if Fields.CONFIGURATION_FIELDS.has(key):
			var limits: Dictionary = Fields.CONFIGURATION_FIELDS[key]
			if not _number(value[key], limits.min, limits.max, limits.get("integer", false)): return false
		elif key == "tuning":
			if not Balance.valid_tuning(value[key]) or value[key].has("session"): return false
		elif key == "waves":
			if not value[key] is Dictionary: return false
			for wave_key in value.waves:
				if not wave_key is String or not wave_key.is_valid_int() or str(int(wave_key)) != wave_key: return false
				var wave_index := int(wave_key)
				if wave_index < 0 or wave_index >= mission.waves.size() or not valid_wave(value.waves[wave_key], mission.routes.size()): return false
		else: return false
	return true

static func valid_wave(value: Variant, lanes: int) -> bool:
	if not value is Dictionary: return false
	for key in value:
		match key:
			"reward":
				if not _number(value.reward, 0, Fields.CONFIGURATION_FIELDS.reward.max): return false
			"tuning":
				if not Balance.valid_tuning(value.tuning) or value.tuning.has("session"): return false
			"groups":
				if not value.groups is Array or value.groups.is_empty() or value.groups.size() > 32: return false
				var total := 0
				for group in value.groups:
					if not group is Array or group.size() != 5: return false
					if not group[0] is String or group[0] not in spawn_kinds(): return false
					for column in Fields.GROUP_FIELDS:
						var limits: Dictionary = Fields.GROUP_FIELDS[column]
						var maximum: float = lanes - 1 if column == 2 else limits.max
						if not _number(group[column], limits.min, maximum, limits.get("integer", false)): return false
					total += int(group[1])
				if total > 5000: return false
			_: return false
	return true

func read_candidate(candidate_path: String) -> Dictionary:
	if not FileAccess.file_exists(candidate_path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(candidate_path)) != OK or not parser.data is Dictionary: return {}
	var envelope: Dictionary = parser.data
	if not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary or not valid_data(parser.data): return {}
	return parser.data

func load_configuration() -> void:
	var best := {}
	var found := false
	for suffix in ["", ".tmp", ".bak"]:
		found = found or FileAccess.file_exists(path + suffix)
		var candidate := read_candidate(path + suffix)
		if not candidate.is_empty() and (best.is_empty() or candidate.sequence > best.sequence): best = candidate
	blocked = found and best.is_empty()
	if not best.is_empty(): data = best
	last_error = "Campaign configuration could not be read. Existing files are preserved." if blocked else ""

func overrides(index: int) -> Dictionary:
	return data.levels.get(str(index), {}).duplicate(true)

func save_level(index: int, configuration: Dictionary) -> bool:
	if blocked or not valid_level(index, configuration):
		if not blocked: last_error = "Invalid campaign configuration."
		return false
	var next := data.duplicate(true)
	if configuration.is_empty(): next.levels.erase(str(index))
	else: next.levels[str(index)] = configuration.duplicate(true)
	next.sequence += 1
	if not write(path, next): return false
	data = next
	return true

static func resolve(index: int, overrides: Dictionary = {}) -> Dictionary:
	var defaults := Catalog.level(index)
	if defaults.is_empty(): return {}
	if not valid_level(index, overrides): overrides = {}
	var attributes := {}
	for key in Fields.CONFIGURATION_FIELDS: attributes[key] = overrides.get(key, defaults.get(key, Catalog.MAX_HEALTH))
	attributes.tuning = Balance.merge_tuning(defaults.tuning, overrides.get("tuning", {}))
	attributes.waves = defaults.waves.duplicate(true)
	var wave_rules := []
	for wave in range(attributes.waves.size()):
		var custom: Dictionary = overrides.get("waves", {}).get(str(wave), {})
		if custom.has("groups"): attributes.waves[wave] = custom.groups.duplicate(true)
		wave_rules.append({"tuning": Balance.merge_tuning(attributes.tuning, custom.get("tuning", {})), "reward": custom.get("reward", attributes.reward)})
	var node = Balance.Content.level(index).derive("level/configured/" + str(index), attributes)
	var mission: Dictionary = node.layout()
	mission.sockets = defaults.sockets
	mission.wave_rules = wave_rules
	return mission

static func schedule(mission: Dictionary, wave: int) -> Array[Dictionary]:
	var node = Balance.Content.wave(mission.index, wave).derive("wave/configured", {"groups": mission.waves[wave]})
	return node.schedule()

# Differences are sparse, but compare against authored defaults as well as inherited overrides.
static func tuning_difference(inherited: Dictionary, effective: Dictionary) -> Dictionary:
	var result := {}
	for category in effective:
		if category == "session": continue
		for kind in effective[category]:
			for stat in effective[category][kind]:
				var value: float = effective[category][kind][stat]
				if is_equal_approx(value, Balance.configuration_value(category, kind, stat, inherited)): continue
				if not result.has(category): result[category] = {}
				if not result[category].has(kind): result[category][kind] = {}
				result[category][kind][stat] = value
	return result

static func _number(value: Variant, minimum: float = 0.0, maximum: float = Balance.MAX_MONEY, integer: bool = false) -> bool:
	return VigilSaveStore.new().number(value, minimum, maximum, integer)

static func spawn_kinds() -> Array[String]:
	var result: Array[String] = []
	for kind in Balance.ENEMIES:
		if Balance.Content.enemy(kind).rule("authored_paths", false): result.append(kind)
	for kind in Balance.BOSSES: result.append(kind)
	return result

static func gameplay_values(tuning: Dictionary) -> Dictionary:
	var result := {}
	for category in Balance.TUNING_FIELDS:
		if category == "session": continue
		result[category] = {}
		for kind in Balance.definitions(category):
			var stats := {}
			for stat in Balance.editable_fields_for(category, kind):
				stats[stat] = Balance.configuration_value(category, kind, stat, tuning)
			result[category][kind] = stats
	return result

static func wave_report(mission: Dictionary, wave: int) -> Dictionary:
	var tuning: Dictionary = mission.wave_rules[wave].tuning
	var groups := []
	var counts := {}
	var health := 0.0
	var reward := 0.0
	for group in mission.waves[wave]:
		var boss := Balance.BOSSES.has(group[0])
		var stats := Balance.definition("bosses" if boss else "enemies", group[0], tuning)
		var hp: float = stats.hp
		var speed: float = stats.speed
		if not boss:
			hp *= Balance.rift_health_multiplier(mission.style, tuning)
			speed *= Balance.rift_speed_multiplier(mission.style, tuning)
		counts[group[0]] = int(counts.get(group[0], 0)) + int(group[1])
		health += hp * group[1]
		reward += stats.payout * group[1]
		groups.append({"kind": group[0], "name": stats.name, "count": int(group[1]), "lane": int(group[2]), "delay_seconds": group[3], "interval_seconds": group[4], "spawn_health": hp, "move_speed": speed, "gold_per_defeat": stats.payout})
	var schedule := schedule(mission, wave)
	return {"wave": wave + 1, "completion_gold": mission.wave_rules[wave].reward, "groups": groups, "schedule": schedule,
		"enemy_counts": counts, "spawn_count": schedule.size(), "last_spawn_seconds": schedule[-1].at if not schedule.is_empty() else 0.0,
		"total_spawn_health": health, "total_defeat_gold": reward, "effective_stats": gameplay_values(tuning)}

static func numeric_changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in after:
		if after[key] is Dictionary:
			var children := numeric_changes(before.get(key, {}), after[key])
			if not children.is_empty(): result[key] = children
		elif (after[key] is int or after[key] is float) and before.get(key) != after[key]:
			result[key] = {"before": before.get(key, 0), "after": after[key], "delta": after[key] - before.get(key, 0)}
	for key in before:
		if not after.has(key) and (before[key] is int or before[key] is float):
			result[key] = {"before": before[key], "after": 0, "delta": -before[key]}
	return result

static func wave_reports(mission: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var previous := {}
	var previous_groups := []
	for wave in mission.waves.size():
		var report := wave_report(mission, wave)
		var compared := {"enemy_counts": report.enemy_counts, "spawn_count": report.spawn_count, "last_spawn_seconds": report.last_spawn_seconds,
			"total_spawn_health": report.total_spawn_health, "total_defeat_gold": report.total_defeat_gold, "completion_gold": report.completion_gold, "effective_stats": report.effective_stats}
		report.changes_from_previous_wave = numeric_changes(previous, compared) if wave > 0 else {}
		if wave > 0 and report.groups != previous_groups:
			report.changes_from_previous_wave.spawn_groups = {"before": previous_groups, "after": report.groups}
		result.append(report)
		previous = compared
		previous_groups = report.groups
	return result

static func export_level(index: int, overrides: Dictionary = {}) -> String:
	if not valid_level(index, overrides): return ""
	var mission := resolve(index, overrides)
	var defaults := resolve(index)
	var baseline := {"gold": defaults.gold, "flame": defaults.flame, "reward": defaults.reward, "tuning": defaults.tuning, "waves": defaults.waves}
	var report := {"version": 1, "level": index + 1, "name": mission.name, "style": mission.style, "defaults": baseline,
		"overrides": overrides.duplicate(true), "effective": {"gold": mission.gold, "flame": mission.flame, "reward": mission.reward, "stats": gameplay_values(mission.tuning)},
		"wave_group_columns": ["kind", "count", "lane", "delay_seconds", "interval_seconds"], "lanes": mission.roads, "waves": wave_reports(mission)}
	var payload := JSON.stringify(report, "", true, true)
	return JSON.stringify({"format": FORMAT, "payload": payload, "checksum": payload.sha256_text()}, "", true, true)
