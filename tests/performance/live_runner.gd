extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rows := []
	var playback := float(OS.get_environment("PERF_PLAYBACK")) if OS.has_environment("PERF_PLAYBACK") else 1.0
	var duration := float(OS.get_environment("PERF_DURATION")) if OS.has_environment("PERF_DURATION") else 5.0
	var repeats := int(OS.get_environment("PERF_REPEATS")) if OS.has_environment("PERF_REPEATS") else 3
	root.size = Vector2i(390,844)
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for mode in ([OS.get_environment("PERF_MODE")] if OS.has_environment("PERF_MODE") else ["infinite", "campaign"]):
		for repeat in range(repeats):
			var app := VigilApp.new()
			app.load_saved_progress = false
			if mode == "infinite":
				app.game = F.infinite(4, true, true)
				for tick in range(600): app.game.combat.tick(Balance.STEP)
			app.game.save_path = "user://performance-live.save"
			root.add_child(app)
			app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			app.set_process(false)
			# Preserve audio event/voice work, silence only this app's output bus.
			AudioServer.set_bus_mute(AudioServer.get_bus_index(app.audio.master_bus_name), true)
			var game = app.game
			var field = app.field
			if mode == "campaign":
				app.show_campaign()
				app.campaign.set_process(false)
				app.campaign.run = F.campaign(29)
				app.campaign.run.wave = app.campaign.run.mission.waves.size() - 1
				app.campaign.connect_run()
				app.campaign.show_battle()
				app.campaign.run.start_wave()
				game = app.campaign.run.game
				field = app.campaign.board
			for frame in range(20): await process_frame
			field.zoom = field.minimum_zoom()
			if mode == "infinite": field.camera = Vector2.ZERO
			for frame in range(10): await process_frame
			var before := F.counts(game)
			var sim_start: float = game.combat.simulation_time
			app.simulation_speed = playback
			field.simulation_rate = playback
			if mode == "campaign": app.campaign.speed = playback
			if mode == "infinite": app.set_process(true)
			else: app.campaign.set_process(true)
			var samples := []
			var start := Time.get_ticks_usec()
			var last := start
			var timeline := []
			var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
			var next_memory_sample := start + 1000000
			while Time.get_ticks_usec() - start < duration * 1000000:
				await process_frame
				var now := Time.get_ticks_usec()
				samples.append((now - last) / 1000.0)
				last = now
				if duration > 5.0 and now >= next_memory_sample:
					timeline.append({"wall_seconds": (now-start)/1000000.0, "simulation_seconds": game.combat.simulation_time-sim_start,
						"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "enemies": game.combat.enemies.size()})
					next_memory_sample = now + 1000000
			app.set_process(false)
			if mode == "campaign": app.campaign.set_process(false)
			var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
			var row := {"mode": mode, "repeat": repeat, "playback": playback, "elapsed_seconds": elapsed, "actual_fps": samples.size()/elapsed,
				"frame_ms": F.stats(samples), "simulation_seconds": game.combat.simulation_time-sim_start,
				"before": before, "after": F.counts(game), "audio_events": app.audio.accepted_events,
				"phase": app.campaign.run.phase if mode == "campaign" else "infinite", "memory_before": memory_before,
				"memory_after": Performance.get_monitor(Performance.MEMORY_STATIC), "timeline": timeline}
			rows.append(row)
			print("LIVE ", row)
			app.free()
			for frame in range(5): await process_frame
	var output := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
