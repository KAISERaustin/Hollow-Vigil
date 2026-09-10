extends SceneTree
## Regenerate the cloud catalog and real client fixtures from shared content nodes.
const Build = preload("res://scripts/persistence/reusable_build.gd")
const Slots = preload("res://scripts/persistence/campaign_slots.gd")

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var catalog := {"stats": {}, "attribute_fields": {}, "levels": [], "spawn_kinds": Build.Configuration.spawn_kinds()}
	for category in Balance.Stats.CATEGORIES:
		catalog.attribute_fields[category] = Balance.Stats.schema(category)
	for category in Build.STAT_GROUPS:
		catalog.stats[category] = {}
		for kind in Balance.definitions(category):
			var fields := {}
			for field in Balance.editable_fields_for(category, kind):
				var limits := Balance.field_limits(category, kind, field)
				fields[field] = {"min": limits.min, "max": limits.max, "integer": limits.get("integer", false)}
			catalog.stats[category][kind] = fields
	for index in Build.Configuration.Catalog.COUNT:
		var level := Build.Configuration.Catalog.level(index)
		catalog.levels.append({"lanes": level.roads.size(), "waves": level.waves.size()})
	var levels := {}
	for index in Build.Configuration.Catalog.COUNT:
		levels[str(index)] = {"overrides": {"gold": 800 + index, "reward": 13 + index, "tuning": {"enemies": {"basic": {"hp": 101 + index}}, "towers": {"rapid": {"damage": 31 + index}}}, "waves": {"0": {"groups": [["basic", 3, 0, 1.5, 0.75, 17 + index]], "reward": 23 + index, "tuning": {"rifts": {"forest": {}}}}}}}
		levels[str(index)].overrides.waves["0"].erase("tuning")
	var build := Build.capture("campaign", null, levels, "all", -1, Build.all_contents("campaign"), "Cloud acceptance", "All thirty levels and specific wave and entity rules")
	assert(not build.is_empty())
	var code := Build.encode(build)
	assert(not code.is_empty())
	var restored := Build.compose_campaign(Build.decode(code), {})
	assert(restored.ok)
	for index in Build.Configuration.Catalog.COUNT:
		var mission := Build.Configuration.resolve(index, restored.levels[str(index)].overrides)
		assert(mission.gold == 800 + index)
		assert(mission.waves[0][0][5] == 17 + index)
		assert(mission.wave_rules[0].reward == 23 + index)
		assert(mission.tuning.enemies.basic.hp == 101 + index)
		assert(mission.tuning.towers.rapid.damage == 31 + index)
	var snapshot := {"version": 1, "sequence": 1, "game_type": "campaign", "id": "12345678-1234-4234-8234-123456789012", "name": "Campaign backup", "mode": "creative", "saved_at": 0, "completed": 30, "stats_version": 1, "levels": levels, "checkpoint": {}}
	assert(Slots.valid(snapshot))
	var waves := Build.capture("campaign", null, levels, "all", -1, {"resources": true, "timing": true, "composition": true, "rewards": true}, "All Campaign waves", "")
	var entities := Build.capture("campaign", null, levels, "level", 29, Build.all_contents("campaign"), "Level 30 entity rules", "")
	var fixtures := {"build": JSON.parse_string(Build.encode(waves)), "entities": JSON.parse_string(Build.encode(entities)), "snapshot": snapshot}
	FileAccess.open("res://artifacts/campaign-cloud-catalog.json", FileAccess.WRITE).store_string(JSON.stringify(catalog))
	FileAccess.open("res://artifacts/campaign-cloud-fixtures.json", FileAccess.WRITE).store_string(JSON.stringify(fixtures))
	print("CAMPAIGN CLOUD CONTRACT: 30 levels preserve resources, entity rules, waves and per-group gold")
	quit()
