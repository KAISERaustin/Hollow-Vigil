extends "res://tests/test_runner.gd"
## Catalog expansion preserves portable content and old mission identities.
const Catalog = preload("res://scripts/campaign/catalog.gd")
const Migration = preload("res://scripts/persistence/campaign_catalog_migration.gd")
const Playthrough = preload("res://scripts/persistence/campaign_playthrough.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
const LevelBuild = preload("res://scripts/persistence/campaign_build.gd")
const Progress = preload("res://scripts/campaign/progress.gd")

func envelope(value: Dictionary, format: String) -> String:
	var payload := JSON.stringify(value)
	return JSON.stringify({"format": format, "payload": payload, "checksum": payload.sha256_text()})

func run() -> void:
	check(Catalog.COUNT == 48 and Catalog.LEVELS_PER_CHAPTER == 8, "Six complete eight-level chapters")
	var current := Build.capture("campaign", null, {}, "all", -1, {"resources": true}, "Expansion", "")
	check(Build.valid(current) and Build.decode(Build.encode(current)) == JSON.parse_string(JSON.stringify(current)), "Current whole campaign round-trips")
	for count in [20, 30]:
		var portable := {"version": 1, "setup": {"name": "Old campaign", "description": ""}, "levels": {}}
		var reusable := current.duplicate(true)
		reusable.erase("catalog_revision")
		reusable.data.levels = {}
		for old in count:
			var mapped := Migration.index(old)
			portable.levels[str(old)] = {"overrides": Playthrough.freeze_level(mapped, {"gold": 1000 + old})}
			reusable.data.levels[str(old)] = current.data.levels[str(mapped)].duplicate(true)
			reusable.data.levels[str(old)].resources.gold = 1000 + old
		var restored := Playthrough.decode(envelope(portable, Playthrough.FORMAT))
		check(not restored.is_empty() and restored.levels.size() == 48, "Old playthrough gains missing defaults")
		var session := preload("res://scripts/campaign/session.gd").new()
		session.data.selections.survival = envelope(portable, Playthrough.FORMAT)
		var original: Dictionary = JSON.parse_string(JSON.stringify(portable))
		check(session.identity("survival") == JSON.stringify(original.levels, "", true, true).sha256_text(), "Legacy shared campaign keeps its existing progress identity")
		var shared := Build.decode(envelope(reusable, Build.FORMAT))
		check(not shared.is_empty() and shared.data.levels.size() == 48, "Old reusable campaign gains missing defaults")
		for old in count:
			var mapped := Migration.index(old)
			check(restored.levels[str(mapped)].overrides.gold == 1000 + old, "Playthrough custom rules retain mission identity")
			check(shared.data.levels[str(mapped)].resources.gold == 1000 + old, "Reusable rules retain mission identity")
		check(Build.compose_campaign(shared, {}).ok, "Migrated shared campaign composes")
		check(Build.decode(Build.encode(shared)) == JSON.parse_string(JSON.stringify(shared)), "Migrated shared campaign never remaps twice")
		var medals: Array = []
		medals.resize(count)
		medals.fill(1)
		var payload := JSON.stringify({"version": 1, "sequence": 1, "medals": medals})
		var path := "user://old-medals-%d.save" % count
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
		file.close()
		check(Progress.new().read_candidate(path).get("completed_levels") == Migration.completed(count), "Legacy victories retain completed chapters")
		clean_test_save(path)
	for old in 30:
		var legacy := {"version": 1, "setup": {"name": "Old level", "description": ""}, "level": old, "overrides": {"gold": 500 + old}}
		var restored := LevelBuild.decode(envelope(legacy, LevelBuild.FORMAT))
		check(not restored.is_empty() and restored.level == Migration.index(old) and restored.overrides.gold == 500 + old, "Single level build keeps identity")
	check(Migration.document({"version": 2, "sequence": 0, "completed_levels": 1, "beaten_levels": "invalid"}, "progress").is_empty(), "Malformed old progression stays rejected")
	check(Migration.level_entries({"09": {"overrides": {}}}).is_empty(), "Malformed old level keys stay rejected")
	print("CAMPAIGN EXPANSION: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
