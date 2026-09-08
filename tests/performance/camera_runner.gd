extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")
const Field = preload("res://tests/performance/render_field.gd")
const Board = preload("res://tests/performance/render_board.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rows := []
	var failures := 0
	for mode in ["infinite", "campaign"]:
		var reference := ""
		for camera_mode in ["watching", "away", "moving"]:
			var field
			var battle
			if mode == "infinite":
				field = Field.new()
				field.state = F.infinite(4, true, true)
			else:
				field = Board.new()
				battle = F.campaign()
				field.run = battle
			root.add_child(field)
			field.set_process(false)
			field.size = Vector2(390, 844)
			var total_ticks := 600 if mode == "infinite" else 2000
			for tick in range(total_ticks):
				field.camera = Vector2.ZERO if camera_mode == "watching" else Vector2(90000, 90000)
				if camera_mode == "moving": field.camera = Vector2(sin(tick * 0.1) * 1200, cos(tick * 0.1) * 600)
				if mode == "infinite": field.state.combat.tick(Balance.STEP)
				else:
					if battle.phase == "planning": battle.start_wave()
					battle.tick(Balance.STEP)
				field.update_view(0.05, 0.0)
				# Exercise the exact visibility query without a GPU in headless mode.
				field.state.combat.visible_enemies(Rect2(field.world(Vector2(-100, -100)), (field.size + Vector2(200, 200)) / field.zoom))
			var digest := F.checksum(field.state)
			if reference.is_empty(): reference = digest
			if reference != digest: failures += 1
			var row := {"mode": mode, "camera": camera_mode, "matches": reference == digest, "checksum": digest, "counts": F.counts(field.state)}
			if mode == "campaign": row["health"] = battle.health; row["phase"] = battle.phase
			rows.append(row)
			print("CAMERA ", mode, " ", camera_mode, " ", row.matches)
			field.free()
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "failures": failures}, "\t"))
	quit(1 if failures else 0)
