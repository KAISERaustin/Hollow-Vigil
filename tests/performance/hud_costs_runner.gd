extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rows := []
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	for mode in ["infinite", "campaign"]:
		var app := VigilApp.new()
		app.load_saved_progress = false
		app.game = F.infinite(4, true)
		app.game.save_path = "user://hud-costs.save"
		root.add_child(app)
		app.set_process(false)
		app.audio.set_suspended(true)
		app.field.hide()
		if mode == "campaign":
			app.show_campaign()
			app.campaign.set_process(false)
			app.campaign.run = F.campaign()
			app.campaign.show_battle()
			app.campaign.board.hide()
		for frame in range(5): await process_frame
		var game = app.game if mode == "infinite" else app.campaign.run.game
		game.data.balance = 1000.0
		for changing in [false, true]:
			for repeat in range(3):
				var samples := []
				for index in range(600):
					if changing: game.data.balance += 1.0
					var start := Time.get_ticks_usec()
					if mode == "infinite": app.update_hud()
					else: app.campaign.refresh()
					if index >= 100: samples.append((Time.get_ticks_usec() - start) / 1000.0)
				rows.append({"mode": mode, "changing": changing, "repeat": repeat, "refresh_ms": F.stats(samples)})
				print("HUD_COST ", rows[-1])
		app.free()
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
