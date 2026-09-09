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
	var count: Variant = value.get("wave_count", mission.waves.size())
	if not _number(count, 1, 10000, true): return false
	for key in value:
		if key == "wave_count": continue
		elif Fields.CONFIGURATION_FIELDS.has(key):
			var limits: Dictionary = Fields.CONFIGURATION_FIELDS[key]
			if not _number(value[key], limits.min, limits.max, limits.get("integer", false)): return false
		elif key == "tuning":
			if not Balance.valid_tuning(value[key]) or value[key].has("session"): return false
		elif key == "waves":
			if not value[key] is Dictionary: return false
			for wave_key in value.waves:
				if not wave_key is String or not wave_key.is_valid_int() or str(int(wave_key)) != wave_key: return false
				var wave_index := int(wave_key)
				if wave_index < 0 or wave_index >= int(count) or not valid_wave(value.waves[wave_key], mission.routes.size()): return false
		else: return false
	# Empty waves are editable placeholders; an entirely empty level is never saved.
	for wave in int(count):
		var fallback: Array = mission.waves[wave] if wave < mission.waves.size() else []
		if not value.get("waves", {}).get(str(wave), {}).get("groups", fallback).is_empty(): return true
	return false

static func valid_wave(value: Variant, lanes: int) -> bool:
	if not value is Dictionary: return false
	for key in value:
		match key:
			"reward":
				if not _number(value.reward, 0, Fields.CONFIGURATION_FIELDS.reward.max): return false
			"tuning":
				if not Balance.valid_tuning(value.tuning) or value.tuning.has("session"): return false
			"groups":
				if not value.groups is Array or value.groups.size() > 32: return false
				var total := 0
				for group in value.groups:
					if not group is Array or group.size() not in [5, 6]: return false
					if group.size() == 6 and not _number(group[5], 0, Fields.CONFIGURATION_FIELDS.reward.max): return false
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

func save_levels(levels: Dictionary) -> bool:
	var next := data.duplicate(true)
	next.levels = levels.duplicate(true)
	next.sequence += 1
	if blocked or not valid_data(next):
		if not blocked: last_error = "Invalid campaign configuration."
		return false
	if not write(path, next): return false
	data = next
	return true

static func with_campaign_tuning(levels: Dictionary, changes: Dictionary) -> Dictionary:
	# Keep the existing portable Level/Wave format, with one transaction for all levels.
	var result := levels.duplicate(true)
	for index in Catalog.COUNT:
		var key := str(index)
		if not result.has(key): result[key] = {"overrides": {}}
		var rules: Dictionary = result[key].overrides
		rules.tuning = Balance.merge_tuning(rules.get("tuning", {}), changes)
		for wave in rules.get("waves", {}).values():
			var tuning: Dictionary = wave.get("tuning", {})
			for category in changes:
				for kind in changes[category]:
					for stat in changes[category][kind]:
						if tuning.get(category, {}).has(kind):
							tuning[category][kind].erase(stat)
					if tuning.get(category, {}).has(kind) and tuning[category][kind].is_empty(): tuning[category].erase(kind)
				if tuning.has(category) and tuning[category].is_empty(): tuning.erase(category)
			if tuning.is_empty(): wave.erase("tuning")
	return result

static func resolve(index: int, level_overrides: Dictionary = {}) -> Dictionary:
	var defaults := Catalog.level(index)
	if defaults.is_empty(): return {}
	if not valid_level(index, level_overrides): level_overrides = {}
	var attributes := {}
	for key in Fields.CONFIGURATION_FIELDS: attributes[key] = level_overrides.get(key, defaults.get(key, Catalog.MAX_HEALTH))
	attributes.tuning = Balance.merge_tuning(defaults.tuning, level_overrides.get("tuning", {}))
	attributes.waves = defaults.waves.duplicate(true)
	attributes.waves.resize(int(level_overrides.get("wave_count", attributes.waves.size())))
	for wave in attributes.waves.size():
		if attributes.waves[wave] == null: attributes.waves[wave] = []
	var wave_rules := []
	for wave in range(attributes.waves.size()):
		var custom: Dictionary = level_overrides.get("waves", {}).get(str(wave), {})
		if custom.has("groups"): attributes.waves[wave] = custom.groups.duplicate(true)
		var wave_tuning: Dictionary = custom.get("tuning", {}).duplicate(true)
		for category in Balance.Stats.CATEGORIES: wave_tuning.erase(category)
		wave_rules.append({"tuning": Balance.merge_tuning(attributes.tuning, wave_tuning), "reward": custom.get("reward", attributes.reward)})
	var node = Balance.Content.level(index).derive("level/configured/" + str(index), attributes)
	var mission: Dictionary = node.layout()
	mission.sockets = defaults.sockets
	mission.wave_rules = wave_rules
	return mission

static func schedule(mission: Dictionary, wave: int) -> Array[Dictionary]:
	var base = Balance.Content.wave(mission.index, wave)
	if base == null: base = Balance.Content.wave(mission.index, 0)
	var node = base.derive("wave/configured", {"groups": mission.waves[wave]})
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
			if category in Balance.Stats.CATEGORIES:
				stats.merge(tuning.get(category, {}).get(kind, {}), true)
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
		var payout: float = group[5] if group.size() == 6 else stats.payout
		reward += payout * group[1]
		groups.append({"kind": group[0], "name": stats.name, "count": int(group[1]), "lane": int(group[2]), "delay_seconds": group[3], "interval_seconds": group[4], "spawn_health": hp, "move_speed": speed, "gold_per_defeat": payout})
	var spawn_schedule := schedule(mission, wave)
	return {"wave": wave + 1, "completion_gold": mission.wave_rules[wave].reward, "groups": groups, "schedule": spawn_schedule,
		"enemy_counts": counts, "spawn_count": spawn_schedule.size(), "last_spawn_seconds": spawn_schedule[-1].at if not spawn_schedule.is_empty() else 0.0,
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

static func export_level(index: int, level_overrides: Dictionary = {}) -> String:
	if not valid_level(index, level_overrides): return ""
	var mission := resolve(index, level_overrides)
	var defaults := resolve(index)
	var baseline := {"gold": defaults.gold, "flame": defaults.flame, "reward": defaults.reward, "tuning": defaults.tuning, "waves": defaults.waves}
	var report := {"version": 1, "level": index + 1, "name": mission.name, "style": mission.style, "defaults": baseline,
		"overrides": level_overrides.duplicate(true), "effective": {"gold": mission.gold, "flame": mission.flame, "reward": mission.reward, "stats": gameplay_values(mission.tuning)},
		"wave_group_columns": ["kind", "count", "lane", "delay_seconds", "interval_seconds", "optional_gold_per_defeat"], "lanes": mission.roads, "waves": wave_reports(mission)}
	var payload := JSON.stringify(report, "", true, true)
	return JSON.stringify({"format": FORMAT, "payload": payload, "checksum": payload.sha256_text()}, "", true, true)
