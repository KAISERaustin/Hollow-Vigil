extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")
const Field = preload("res://tests/performance/render_field.gd")
const Board = preload("res://tests/performance/render_board.gd")
const Run = preload("res://scripts/campaign/run.gd")
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 240.0)
	call_deferred("run")

static func stable(value: Variant) -> Variant:
	if value is VigilContentNode: return {"content": value.id}
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a,b): return str(a) < str(b))
		for key in keys:
			# Derived optimization data is deliberately outside authoritative state.
			if key in ["_route_geometry", "distance_remaining", "snapshot_stats", "snapshot"]: continue
			result[key] = stable(value[key])
		return result
	if value is Array:
		var result := []
		for child in value: result.append(stable(child))
		return result
	return value

static func state(game: VigilState, battle = null) -> Dictionary:
	var combat := game.combat
	var result := {"enemies": combat.enemies, "towers": game.data.towers,
		"balance": game.data.balance, "kills": game.data.kills, "escapes": game.data.escapes,
		"earnings": game.data.lifetime_earnings, "unclaimed": game.economy.unclaimed(),
		"projectiles": combat.pending_shots, "line_projectiles": combat.line_projectiles,
		"traps": combat.traps, "fields": combat.effect_fields, "burning": combat.burning_ground,
		"locks": combat.target_locks, "curses": combat.curses, "relic_progress": combat.relic_progress,
		"tower_components": combat.tower_component_state, "relic_epochs": combat.relic_epochs,
		"relic_drops": combat.relic_drops, "relics": game.data.relics, "income_events": combat.income_events,
		"random_state": combat.rng.state, "time": combat.simulation_time, "spawned": combat.enemy_serial}
	if battle != null:
		result.campaign = [battle.health, battle.phase, battle.wave, battle.wave_time, battle.next_spawn, battle.schedule]
	return stable(result)

static func digest(value: Variant) -> String:
	return var_to_bytes(stable(value)).hex_encode().sha256_text()

func run() -> void:
	var rows := []
	for mode in ["infinite", "campaign"]:
		var reference := []
		for camera_mode in ["watching", "hidden", "moving"]:
			var field
			var battle
			if mode == "infinite":
				field = Field.new(); field.state = F.infinite(4, true, true)
			else:
				field = Board.new(); battle = F.campaign(); field.run = battle
				field.state = battle.game
			field.state.combat.rng.seed = 570
			root.add_child(field)
			field.set_process(false)
			field.size = Vector2(390, 844)
			field.zoom = 0.35
			var checkpoints := []
			for tick in range(600):
				# Fully outside these fixtures, without projecting tiny native portal
				# polygons at artificial 90,000-unit floating-point coordinates.
				field.camera = Vector2.ZERO if camera_mode == "watching" else Vector2(0, 12 * Balance.TILE)
				if camera_mode == "moving": field.camera = Vector2(sin(tick*0.03)*1300, cos(tick*0.03)*800)
				if battle == null: field.state.combat.tick(Balance.STEP)
				else:
					if battle.phase == "planning": battle.start_wave()
					battle.tick(Balance.STEP)
				field.update_view(Balance.STEP, 0.0)
				if tick % 100 == 99: checkpoints.append(digest(state(field.state, battle)))
				if OS.get_environment("PERF_RENDER_CAMERA") == "1" and tick % 10 == 9:
					await process_frame
					await RenderingServer.frame_post_draw
			if camera_mode == "hidden":
				var view := Rect2(field.world(Vector2.ZERO), field.size / field.zoom)
				if not field.state.combat.visible_enemies(view).is_empty(): failures += 1
			if reference.is_empty(): reference = checkpoints
			if reference != checkpoints: failures += 1
			rows.append({"mode": mode, "camera": camera_mode, "checkpoints": checkpoints, "matches": reference == checkpoints,
				"state": state(field.state, battle)})
			print("BEHAVIOR ", mode, " ", camera_mode, " matches=", reference == checkpoints)
			field.free()
	# Compare save/restoration outcomes across revisions with unchanged save rules:
	# Infinite restores bosses; Campaign resumes its saved wave-start checkpoint.
	var game := F.infinite(4, true)
	for tick in range(140): game.combat.tick(Balance.STEP)
	game.data.last_accounted = 1700000000.0
	game.save_path = "user://optimization-behavior.save"
	if not game.save(1700000000.0): failures += 1
	var restored := VigilState.new(570)
	restored.save_path = game.save_path
	if not restored.load_save(1700000000.0): failures += 1
	restored.combat.rng.seed = 570
	for tick in range(140): restored.combat.tick(Balance.STEP)
	rows.append({"mode": "infinite_restored", "checksum": digest(state(restored)), "state": state(restored)})
	var campaign = F.campaign()
	campaign.game.combat.rng.seed = 570
	campaign.start_wave()
	for tick in range(140): campaign.tick(Balance.STEP)
	var resumed = Run.from_checkpoint(campaign.checkpoint())
	if resumed == null:
		failures += 1
	else:
		for tick in range(140): resumed.tick(Balance.STEP)
		var matches := digest(state(campaign.game, campaign)) == digest(state(resumed.game, resumed))
		if not matches: failures += 1
		rows.append({"mode": "campaign_restored", "checksum": digest(state(resumed.game, resumed)), "matches": matches, "state": state(resumed.game, resumed)})
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "failures": failures}, "\t"))
	quit(1 if failures else 0)
