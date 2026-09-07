extends RefCounted
## Composes selected content nodes into fresh games. Never applies to a live game.
const FORMAT := "hollow-vigil-reusable-build-v2"
const MAX_BYTES := 16 * 1024 * 1024
const Configuration = preload("res://scripts/campaign/configuration.gd")
const LevelBuild = preload("res://scripts/persistence/campaign_build.gd")
const Stats = preload("res://scripts/persistence/stat_configuration.gd")
const GROUPS = preload("res://scripts/content/catalogs/build_groups.gd")
const STAT_GROUPS := ["enemies", "bosses", "towers", "gear", "rifts"]

static func groups(game_type: String) -> Array:
	return Balance.Content.catalog().children("build_contents").filter(func(node): return node.rule("export_game_type", node.rule("game_type")) in ["both", game_type])

static func all_contents(game_type: String, option: String = "") -> Dictionary:
	var selected := {}
	for group in groups(game_type):
		if not option.is_empty() and group.rule("selection_group") != option: continue
		var key: String = group.id.get_slice("/", 1)
		selected[key] = group.types() if key in STAT_GROUPS else true
	return selected

static func grouped_contents(game_type: String, contents: Dictionary) -> Dictionary:
	# Older partial builds remain readable; reopening the form selects whole groups.
	var selected := {}
	for option in GROUPS.OPTIONS:
		var members := all_contents(game_type, option)
		for key in members:
			var value: Variant = contents.get(key, false)
			if (value is Array and not value.is_empty()) or (value is bool and value):
				selected.merge(members)
				break
	return selected

static func selected_stats(tuning: Dictionary, contents: Dictionary) -> Dictionary:
	var result := {}
	for category in STAT_GROUPS:
		if not contents.get(category, []).is_empty():
			result[category] = Balance.Content.catalog().find("build_contents", category).capture(tuning, contents[category])
	return result

static func summary(value: Dictionary) -> String:
	var items: PackedStringArray = []
	for key in value.get("contents", {}):
		var selection: Variant = value.contents[key]
		if selection is Array:
			var names: PackedStringArray = []
			for kind in selection: names.append(Balance.definitions(key)[kind].name)
			items.append(GROUPS.DEFINITIONS[key].name + ": " + ", ".join(names))
		elif selection == true:
			items.append(GROUPS.DEFINITIONS[key].name)
	return "\n".join(items)

static func scope_label(value: Dictionary) -> String:
	if value.game_type == "infinite": return "Infinite"
	return "Whole campaign" if value.scope == "all" else "Level %d · %s" % [int(value.level) + 1, Configuration.Catalog.level(int(value.level)).name]

static func has_stats(value: Dictionary) -> bool:
	for key in STAT_GROUPS:
		if not value.get("contents", {}).get(key, []).is_empty(): return true
	return false

static func compatible(value: Dictionary, target: String) -> bool:
	return value.get("game_type") == target or has_stats(value)

static func dependencies(value: Dictionary) -> String:
	var notes: PackedStringArray = []
	if value.contents.get("layout", false):
		notes.append("Layout includes compatible equipment and its " + ("placement tiles and connecting paths." if value.game_type == "infinite" else "authored level sockets."))
	if value.contents.get("timing", false) != value.contents.get("composition", false):
		notes.append("Wave groups must match the original group count. Select both wave groups if you added or removed spawn groups.")
	if value.game_type == "campaign" and has_stats(value):
		notes.append("Level defaults can travel between game types. Wave-specific stat changes stay in Campaign.")
	return "\n".join(notes)

static func clean_loadout(data: Dictionary) -> Dictionary:
	var result := {"towers": data.towers.duplicate(true), "next_tower": data.next_tower, "relics": data.get("relics", {}).duplicate(true)}
	for tower in result.towers.values():
		tower.cooldown = 0.0
		tower.earnings = 0.0
		tower.erase("rebuild_remaining")
	return result

static func clean_regions(data: Dictionary, all_tiles: bool) -> Dictionary:
	var wanted := {"0,0": true}
	if all_tiles:
		for key in data.regions: wanted[key] = true
	else:
		for tower in data.towers.values():
			var key: String = tower.region
			while not wanted.has(key) and data.regions.has(key):
				wanted[key] = true
				key = data.regions[key].parent
	var result := {}
	for key in wanted:
		var region: Dictionary = data.regions[key].duplicate(true)
		region.history = {}
		region.history_time = 0.0
		region.timer = 0.0
		region.erase("boss")
		if not all_tiles:
			region.unlocks = []
			region.traffic = 0
		result[key] = region
	return result

static func capture(game_type: String, source: VigilState, levels: Dictionary, scope: String, level: int, contents: Dictionary, title: String, description: String) -> Dictionary:
	# Export availability is separate from validation so old builds stay readable.
	contents = contents.duplicate(true)
	var available := all_contents(game_type)
	for key in contents.keys():
		if not available.has(key): contents.erase(key)
	var value := {"version": 2, "setup": {"name": title.strip_edges(), "description": description}, "game_type": game_type,
		"scope": scope if game_type == "campaign" else "all", "level": level if game_type == "campaign" and scope == "level" else -1,
		"contents": contents.duplicate(true), "data": {}}
	for key in value.contents.keys():
		if (value.contents[key] is bool and not value.contents[key]) or (value.contents[key] is Array and value.contents[key].is_empty()): value.contents.erase(key)
	if game_type == "infinite":
		value.data.stats = selected_stats(source.tuning, contents)
		if contents.get("resources", false): value.data.resources = {"gold": source.tuning.get("session", {}).get("start", {}).get("starting_gold", source.data.balance)}
		if contents.get("layout", false): value.data.layout = clean_loadout(source.data)
		if contents.get("terrain", false) or contents.get("layout", false):
			value.data.map = {"seed": source.data.seed, "regions": clean_regions(source.data, contents.get("terrain", false))}
	else:
		value.data.levels = {}
		for index in ([level] if scope == "level" else range(Configuration.Catalog.COUNT)):
			var source_level: Dictionary = levels.get(str(index), {})
			var mission := Configuration.resolve(index, source_level.get("overrides", {}))
			var entry := {"stats": selected_stats(mission.tuning, contents), "waves": {}}
			if contents.get("resources", false): entry.resources = {"gold": mission.gold, "flame": mission.flame}
			if contents.get("layout", false) and source_level.has("loadout"): entry.layout = clean_loadout(source_level.loadout)
			for wave in mission.waves.size():
				var part := {"stats": selected_stats(mission.wave_rules[wave].tuning, contents)}
				if contents.get("timing", false):
					part.timing = []
					for group in mission.waves[wave]: part.timing.append([group[1], group[3], group[4]])
				if contents.get("composition", false):
					part.composition = []
					for group in mission.waves[wave]: part.composition.append([group[0], group[2]])
				if contents.get("rewards", false): part.reward = mission.wave_rules[wave].reward
				entry.waves[str(wave)] = part
			value.data.levels[str(index)] = entry
	return value if valid(value) else {}

static func encode(value: Dictionary) -> String:
	if not valid(value): return ""
	var payload := JSON.stringify(value, "", true, true)
	var code := JSON.stringify({"format": FORMAT, "payload": payload, "checksum": payload.sha256_text()})
	return code if code.to_utf8_buffer().size() <= MAX_BYTES else ""

static func decode(code: String) -> Dictionary:
	if code.to_utf8_buffer().size() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(code) != OK: return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.size() != 3 or envelope.get("format") != FORMAT or not envelope.get("payload") is String: return {}
	if envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK: return {}
	var value: Variant = parser.data
	return value if value is Dictionary and valid(value) else {}

static func valid(value: Dictionary) -> bool:
	if value.size() != 7 or value.get("version") != 2 or value.get("game_type") not in ["campaign", "infinite"]: return false
	if not Stats.valid({"version": 1, "setup": value.get("setup"), "tuning": {}}): return false
	if value.get("scope") not in ["all", "level"] or not Configuration._number(value.get("level"), -1, Configuration.Catalog.COUNT - 1, true): return false
	if (value.scope == "level") != (int(value.level) >= 0) or (value.game_type == "infinite" and value.scope != "all"): return false
	if not value.get("contents") is Dictionary or value.contents.is_empty() or not value.get("data") is Dictionary: return false
	for key in value.contents:
		if not GROUPS.DEFINITIONS.has(key) or GROUPS.DEFINITIONS[key].get("game_type", value.game_type) != value.game_type: return false
		var selection: Variant = value.contents[key]
		if key in STAT_GROUPS:
			if not selection is Array or selection.is_empty(): return false
			var seen := {}
			for kind in selection:
				if not kind is String or seen.has(kind) or kind not in Balance.Content.catalog().find("build_contents", key).types(): return false
				seen[kind] = true
		elif selection != true: return false
	if value.game_type == "infinite":
		if not _valid_stats(value.data.get("stats"), value.contents): return false
		var composed := infinite_snapshot(value, {}, "creative")
		return composed.get("ok", false)
	if value.data.size() != 1 or not value.data.get("levels") is Dictionary: return false
	if value.scope == "all" and value.data.levels.size() not in [Configuration.Catalog.LEGACY_COUNT, Configuration.Catalog.COUNT]: return false
	var indices: Array = [int(value.level)] if value.scope == "level" else range(value.data.levels.size())
	if value.data.levels.size() != indices.size(): return false
	for index in indices:
		var entry: Variant = value.data.levels.get(str(index))
		if not entry is Dictionary or not _valid_stats(entry.get("stats"), value.contents) or not entry.get("waves") is Dictionary: return false
		var defaults := Configuration.Catalog.level(index)
		if entry.waves.size() != defaults.waves.size(): return false
		for wave in defaults.waves.size():
			var part: Variant = entry.waves.get(str(wave))
			if not part is Dictionary or not _valid_stats(part.get("stats"), value.contents): return false
			if not _valid_wave_part(part, value.contents, defaults.roads.size()): return false
		var composed := campaign_level(value, index)
		# Missing companion groups are a reviewable content conflict, not bad data.
		if not composed.ok and not composed.get("dependency", false): return false
	return true

static func _valid_stats(tuning: Variant, contents: Dictionary) -> bool:
	if not Balance.valid_tuning(tuning) or tuning.has("session"): return false
	for category in tuning:
		for kind in tuning[category]:
			if kind.get_slice(":", 0) not in contents.get(category, []): return false
	for category in STAT_GROUPS:
		for kind in contents.get(category, []):
			for key in Balance.definitions(category):
				if key.get_slice(":", 0) == kind:
					if not tuning.get(category, {}).has(key): return false
					for stat in Balance.editable_fields_for(category, key):
						if not tuning[category][key].has(stat): return false
	return true

static func _valid_wave_part(part: Dictionary, contents: Dictionary, lanes: int) -> bool:
	for key in part:
		if key not in ["stats", "timing", "composition", "reward"]: return false
	if part.has("reward") != contents.get("rewards", false) or part.has("timing") != contents.get("timing", false) or part.has("composition") != contents.get("composition", false): return false
	if part.has("reward") and not Configuration._number(part.reward, 0, Configuration.Fields.CONFIGURATION_FIELDS.reward.max): return false
	for key in ["timing", "composition"]:
		if not part.has(key): continue
		if not part[key] is Array or part[key].is_empty() or part[key].size() > 32: return false
		for group in part[key]:
			if not group is Array: return false
			if key == "timing":
				if group.size() != 3: return false
				for column in 3:
					var limits: Dictionary = Configuration.Fields.GROUP_FIELDS[[1, 3, 4][column]]
					if not Configuration._number(group[column], limits.min, limits.max, limits.get("integer", false)): return false
			else:
				if group.size() != 2 or group[0] not in Configuration.spawn_kinds() or not Configuration._number(group[1], 0, lanes - 1, true): return false
	return true

static func campaign_level(value: Dictionary, index: int) -> Dictionary:
	var entry: Dictionary = value.data.levels[str(index)]
	for key in entry:
		if key not in ["stats", "waves", "resources", "layout"]: return {"ok": false}
	if entry.has("resources") != value.contents.get("resources", false) or (entry.has("layout") and not value.contents.get("layout", false)): return {"ok": false}
	var overrides := {"tuning": entry.stats.duplicate(true), "waves": {}}
	if entry.has("resources"):
		if not entry.resources is Dictionary or entry.resources.size() != 2: return {"ok": false}
		overrides.merge(entry.resources, true)
	var defaults := Configuration.Catalog.level(index)
	for wave in defaults.waves.size():
		var part: Dictionary = entry.waves[str(wave)]
		var spawn_groups: Array = defaults.waves[wave].duplicate(true)
		if part.has("timing") and part.has("composition"):
			if part.timing.size() != part.composition.size(): return {"ok": false}
			spawn_groups = []
			for group in part.timing.size(): spawn_groups.append([part.composition[group][0], part.timing[group][0], part.composition[group][1], part.timing[group][1], part.timing[group][2]])
		elif part.has("timing") or part.has("composition"):
			var key := "timing" if part.has("timing") else "composition"
			if part[key].size() != spawn_groups.size():
				return {"ok": false, "dependency": true, "error": "Level %d, wave %d has a different number of spawn groups. Save both Wave timing and counts and Enemy types and entrances to keep those groups together." % [index + 1, wave + 1]}
			for group in spawn_groups.size():
				if key == "timing":
					for column in 3: spawn_groups[group][[1, 3, 4][column]] = part.timing[group][column]
				else:
					spawn_groups[group][0] = part.composition[group][0]
					spawn_groups[group][2] = part.composition[group][1]
		var custom := {"tuning": part.stats.duplicate(true)}
		if part.has("timing") or part.has("composition"): custom.groups = spawn_groups
		if part.has("reward"): custom.reward = part.reward
		overrides.waves[str(wave)] = custom
	var level := {"version": 1, "setup": value.setup, "level": index, "overrides": overrides}
	if entry.has("layout"):
		if not entry.layout is Dictionary or entry.layout.size() != 3: return {"ok": false}
		level.loadout = entry.layout.duplicate(true)
		level.loadout.balance = overrides.get("gold", defaults.gold)
	return {"ok": LevelBuild.valid(level), "level": level}

static func portable_stats(value: Dictionary, choices: Dictionary) -> Dictionary:
	if value.game_type == "infinite": return {"ok": true, "tuning": value.data.stats.duplicate(true)}
	var index := int(value.level)
	if value.scope == "all":
		if not choices.has("source_level"): return {"ok": false, "error": "Choose which level's starting stats to use."}
		index = int(choices.source_level)
	if not value.data.levels.has(str(index)): return {"ok": false, "error": "Choose a level included in this build."}
	return {"ok": true, "tuning": value.data.levels[str(index)].stats.duplicate(true)}

static func infinite_snapshot(value: Dictionary, choices: Dictionary, mode: String) -> Dictionary:
	var stats := portable_stats(value, choices)
	if not stats.ok: return stats
	var data: Dictionary = value.data if value.game_type == "infinite" else {}
	for key in data:
		if key not in ["stats", "resources", "layout", "map"]: return {"ok": false}
	if value.game_type == "infinite":
		if data.has("resources") != value.contents.get("resources", false) or data.has("layout") != value.contents.get("layout", false): return {"ok": false}
		if data.has("map") != (value.contents.get("terrain", false) or value.contents.get("layout", false)): return {"ok": false}
	var seed_value := 0
	if data.has("map"):
		if not data.map is Dictionary or data.map.size() != 2 or not Configuration._number(data.map.get("seed"), 0, 1e15, true) or not data.map.get("regions") is Dictionary: return {"ok": false}
		seed_value = int(data.map.seed)
	var game := VigilState.new(seed_value, mode, stats.tuning)
	var snapshot := game.data.duplicate(true)
	snapshot.setup = value.setup.duplicate(true)
	if data.has("resources"):
		if not data.resources is Dictionary or data.resources.size() != 1 or not Configuration._number(data.resources.get("gold")): return {"ok": false}
		snapshot.balance = data.resources.gold
	if data.has("map"):
		snapshot.regions = data.map.regions.duplicate(true)
		snapshot.first_property_required = snapshot.regions.size() <= 1
	if data.has("layout"):
		if not data.layout is Dictionary or data.layout.size() != 3 or not data.layout.has_all(["towers", "next_tower", "relics"]): return {"ok": false}
		snapshot.merge(data.layout.duplicate(true), true)
	return {"ok": VigilSaveStore.new().valid_data(snapshot), "snapshot": snapshot}

static func compose_campaign(value: Dictionary, choices: Dictionary) -> Dictionary:
	var levels := {}
	if value.game_type == "campaign":
		for key in value.data.levels:
			var composed := campaign_level(value, int(key))
			if not composed.ok: return composed
			levels[key] = {"overrides": composed.level.overrides}
			if composed.level.has("loadout"): levels[key].loadout = composed.level.loadout
	else:
		if choices.get("apply_to", "") not in ["all", "level"]: return {"ok": false, "error": "Choose Whole campaign or One level for these stats."}
		if choices.apply_to == "level" and not Configuration._number(choices.get("target_level"), 0, Configuration.Catalog.COUNT - 1, true): return {"ok": false, "error": "Choose the level that will use these stats."}
		for index in ([int(choices.target_level)] if choices.apply_to == "level" else range(Configuration.Catalog.COUNT)):
			levels[str(index)] = {"overrides": {"tuning": value.data.stats.duplicate(true)}}
	return {"ok": true, "levels": levels}
