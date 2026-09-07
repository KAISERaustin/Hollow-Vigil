extends "res://tests/test_runner.gd"
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Run = preload("res://scripts/campaign/run.gd")

func run() -> void:
	for index in range(Configuration.Catalog.COUNT):
		var code := Configuration.export_level(index)
		check(code == Configuration.export_level(index), "Level %d export deterministic" % (index + 1))
		var envelope: Dictionary = JSON.parse_string(code)
		check(envelope.format == Configuration.FORMAT and envelope.checksum == envelope.payload.sha256_text(), "Export uses existing checked-envelope convention")
		var report: Dictionary = JSON.parse_string(envelope.payload)
		check(report.level == index + 1 and report.waves.size() == Configuration.Catalog.level(index).waves.size(), "Export contains one whole level")
		for key in ["towers", "regions", "cloud", "completed_levels", "sequence", "kills", "active_seconds"]:
			check(not report.has(key), "Export excludes unrelated runtime " + key)
		var mission := Configuration.resolve(index)
		for wave in range(report.waves.size()):
			check(report.waves[wave].spawn_count == Configuration.schedule(mission, wave).size(), "Exported wave count matches scheduling")
	var overrides := {"tuning": {"towers": {"rapid": {"cost": 120.0}}}, "waves": {"1": {"tuning": {"enemies": {"basic": {"hp": 100.0}}, "towers": {"rapid:2": {"cost": 37.0}}}, "groups": [["basic", 3, 0, 2, 0.5]], "reward": 71.0}}}
	var configured := Configuration.resolve(6, overrides)
	var waves := Configuration.wave_reports(configured)
	check(waves[1].effective_stats.towers["rapid:2"].cost == 37.0, "Exported upgrade price uses transaction calculation")
	check(waves[1].changes_from_previous_wave.effective_stats.towers["rapid:2"].cost == {"before": 120.0, "after": 37.0, "delta": -83.0}, "Per-wave changes expose upgrade cost differences")
	var battle := Run.new(6, overrides)
	battle.wave = 1
	battle.start_wave()
	battle.tick(2.0)
	check(battle.game.combat.enemies[0].max_hp == waves[1].groups[0].spawn_health, "Exported health matches actual campaign spawn including biome effect")
	check(waves[1].groups[0].spawn_health == 125.0 and waves[1].total_spawn_health == 375.0, "Wave totals reflect custom stats and biome modifiers")
	check(Configuration.export_level(6, {"gold": -1}).is_empty(), "Invalid configuration cannot be exported")
	print("CAMPAIGN EXPORT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
