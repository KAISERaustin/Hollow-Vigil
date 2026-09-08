extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")
var rows := []

func _initialize() -> void:
	call_deferred("run")

func measure(label: String, callback: Callable, count: int, units: int = 1) -> void:
	for warm in range(5): callback.call()
	var samples := []
	for i in range(count):
		var start := Time.get_ticks_usec()
		callback.call()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	var row := {"label": label, "units_per_call": units, "ms": F.stats(samples)}
	rows.append(row)
	print("COST ", row)

func run() -> void:
	for defended in [false, true]:
		var game := F.infinite(40, defended)
		for step in range(900): game.combat.tick(Balance.STEP)
		var prefix := "defended" if defended else "undefended"
		measure(prefix + ".all_enemy_speed_resolution", func():
			for enemy in game.combat.enemies: game.combat.enemy_speed(enemy)
		, 100, game.combat.enemies.size())
		measure(prefix + ".rebuild_enemy_index", game.combat.rebuild_enemy_index, 100, game.combat.enemies.size())
		measure(prefix + ".rebuild_id_map", func():
			var ids := {}
			for enemy in game.combat.enemies: ids[enemy.id] = enemy
		, 100, game.combat.enemies.size())
		measure(prefix + ".all_remaining_distances", func():
			for enemy in game.combat.enemies: game.combat.distance_remaining(enemy)
		, 30, game.combat.enemies.size())
		var suffix_by_enemy := {}
		var max_error := 0.0
		for enemy in game.combat.enemies:
			var route: Array = enemy.path
			var suffix := PackedFloat64Array()
			suffix.resize(route.size())
			for segment in range(route.size() - 2, -1, -1): suffix[segment] = suffix[segment + 1] + route[segment].distance_to(route[segment + 1])
			suffix_by_enemy[enemy.id] = suffix
			var fast: float = enemy.pos.distance_to(route[enemy.segment]) + suffix[enemy.segment]
			max_error = maxf(max_error, absf(fast - game.combat.distance_remaining(enemy)))
		measure(prefix + ".experimental_remaining_distance_suffix_lookup", func():
			for enemy in game.combat.enemies:
				var _distance: float = enemy.pos.distance_to(enemy.path[enemy.segment]) + suffix_by_enemy[enemy.id][enemy.segment]
		, 100, game.combat.enemies.size())
		rows.append({"label": prefix + ".suffix_equivalence", "max_absolute_error": max_error, "note": "Isolated calculation experiment; not integrated into combat."})
		measure(prefix + ".close_visibility_query", func(): game.combat.visible_enemies(Rect2(-300,-500,600,1000)), 100)
		measure(prefix + ".wide_visibility_query", func(): game.combat.visible_enemies(Rect2(-12500,-500,25000,1000)), 100)
		if defended:
			measure("defended.all_tower_stats", func():
				for tower in game.data.towers.values(): Balance.tower_stats(tower, game.tuning, game.data.relics)
			, 100, game.data.towers.size())
			measure("defended.all_tower_component_sync", func(): game.combat.TowerComponents.sync(game.combat), 100, game.data.towers.size())
		measure(prefix + ".save_snapshot_validation_write", func():
			assert(game.storage.write("user://performance-cost.save", game.snapshot()), game.storage.last_error)
		, 20)
	var source := OS.get_environment("PERF_SAVE_INPUT")
	if not source.is_empty() and FileAccess.file_exists(source):
		var save := VigilSaveStore.new().read_candidate(source)
		if not save.is_empty():
			var game := VigilState.new()
			game.save_path = "user://copied-live-save.save"
			DirAccess.copy_absolute(source, ProjectSettings.globalize_path(game.save_path))
			game.load_save(save.last_accounted)
			game.combat.rng.seed = 570
			for tick in range(600): game.combat.tick(Balance.STEP)
			measure("copied_local_save.tick", func(): game.combat.tick(Balance.STEP), 300)
			rows.append({"local_save_counts": F.counts(game), "note": "Private save contents are not included in this report."})
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
