extends RefCounted
const Migration = preload("res://scripts/persistence/campaign_catalog_migration.gd")
## Portable composition of Level and Wave configurations; never completion or combat state.
const FORMAT := "hollow-vigil-campaign-playthrough-v1"
const LevelBuild = preload("res://scripts/persistence/campaign_build.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Stats = preload("res://scripts/persistence/stat_configuration.gd")
const MAX_BYTES := 8 * 1024 * 1024

static func freeze_level(index: int, overrides: Dictionary) -> Dictionary:
	var mission := Configuration.resolve(index, overrides)
	var result := {"gold": mission.gold, "flame": mission.flame, "reward": mission.reward,
		"tuning": Configuration.gameplay_values(mission.tuning), "waves": {}}
	if overrides.has("wave_count"): result.wave_count = mission.waves.size()
	for wave in mission.waves.size():
		result.waves[str(wave)] = {"groups": mission.waves[wave].duplicate(true),
			"reward": mission.wave_rules[wave].reward, "tuning": Configuration.tuning_difference(result.tuning, mission.wave_rules[wave].tuning)}
	return result

static func encode(levels: Dictionary, title: String, description: String, stats_only: bool = false) -> String:
	var value := {"catalog_revision": 2, "version": 1, "setup": {"name": title.strip_edges(), "description": description}, "levels": {}}
	for index in Configuration.Catalog.COUNT:
		var source: Dictionary = levels.get(str(index), {})
		if not Configuration.valid_level(index, source.get("overrides", {})): return ""
		var entry := {"overrides": freeze_level(index, source.get("overrides", {}))}
		if not stats_only and source.has("loadout"): entry.loadout = source.loadout.duplicate(true)
		value.levels[str(index)] = entry
	if not valid(value): return ""
	var payload := JSON.stringify(value, "", true, true)
	var code := JSON.stringify({"format": FORMAT, "payload": payload, "checksum": payload.sha256_text()})
	return code if code.to_utf8_buffer().size() <= MAX_BYTES else ""

static func valid(value: Variant) -> bool:
	if value is Dictionary and value.has("catalog_revision") and value.catalog_revision != 2: return false
	if not value is Dictionary or value.size() != (4 if value.has("catalog_revision") else 3) or value.get("version") != 1: return false
	if not Stats.valid({"version": 1, "setup": value.get("setup"), "tuning": {}}): return false
	if not value.get("levels") is Dictionary or value.levels.size() not in [Configuration.Catalog.LEGACY_COUNT, 30, Configuration.Catalog.COUNT]: return false
	for index in value.levels.size():
		var entry: Variant = value.levels.get(str(index))
		if not entry is Dictionary or entry.size() != (2 if entry.has("loadout") else 1): return false
		var level := {"version": 1, "setup": value.setup, "level": index, "overrides": entry.get("overrides")}
		if entry.has("loadout"): level.loadout = entry.loadout
		if not LevelBuild.valid(level): return false
		if level.overrides.size() != (6 if level.overrides.has("wave_count") else 5) or not level.overrides.has_all(["gold", "flame", "reward", "tuning", "waves"]): return false
		if level.overrides.waves.size() != int(level.overrides.get("wave_count", Configuration.Catalog.level(index).waves.size())): return false
		for wave in level.overrides.waves.values():
			if wave.size() != 3 or not wave.has_all(["groups", "reward", "tuning"]): return false
	return true

static func decode(code: String) -> Dictionary:
	if code.to_utf8_buffer().size() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(code) != OK or not parser.data is Dictionary: return {}
	var envelope: Dictionary = parser.data
	if envelope.size() != 3 or envelope.get("format") != FORMAT or not envelope.get("payload") is String: return {}
	if envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary: return {}
	var value := Migration.document(parser.data, "playthrough")
	if value.is_empty(): return {}
	for index in Configuration.Catalog.COUNT:
		if not value.levels.has(str(index)): value.levels[str(index)] = {"overrides": freeze_level(index, {})}
	return value if valid(value) else {}

static func level_build(value: Dictionary, index: int) -> Dictionary:
	if value.is_empty() or not value.levels.has(str(index)): return {}
	var result: Dictionary = value.levels[str(index)].duplicate(true)
	result.merge({"version": 1, "setup": value.setup.duplicate(true), "level": index})
	return result
