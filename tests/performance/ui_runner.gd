extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")
const Probe = preload("res://tests/performance/probe.gd")
var rows := []

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in range(10):
		await process_frame
		await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for mode in ["infinite", "campaign"]:
		for variant in ["full", "no_simulation", "no_render", "no_ui_refresh"]:
			for repeat in range(3):
				Probe.enabled = false
				var app := VigilApp.new()
				app.load_saved_progress = false
				if mode == "infinite":
					app.game = F.infinite(4, true, true)
					for step in range(600): app.game.combat.tick(Balance.STEP)
				app.game.save_path = "user://performance-ui.save"
				root.add_child(app)
				app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				app.set_process(false)
				# Baseline audio stays attached; suspend output for repeatable silent measurements.
				app.audio.set_suspended(true)
				var field = app.field
				var game = app.game
				if mode == "campaign":
					app.show_campaign()
					app.campaign.set_process(false)
					app.campaign.run = F.campaign()
					app.campaign.show_battle()
					F.populate_campaign(app.campaign.run, 500)
					field = app.campaign.board
					game = app.campaign.run.game
				field.set_process(false)
				Engine.max_fps = 0
				await settle()
				field.zoom = field.minimum_zoom()
				if mode == "infinite": field.camera = Vector2.ZERO
				field.visible = variant != "no_render"
				await settle()
				Probe.reset()
				Probe.enabled = true
				var samples := []
				var tick_samples := []
				var refresh_samples := []
				var maintenance_samples := []
				var last := Time.get_ticks_usec()
				for frame in range(360):
					await process_frame
					var now := Time.get_ticks_usec()
					if frame > 0: samples.append((now - last) / 1000.0)
					last = now
					if variant != "no_simulation" and frame % 3 == 0:
						var start := Time.get_ticks_usec()
						game.combat.tick(Balance.STEP)
						tick_samples.append((Time.get_ticks_usec() - start) / 1000.0)
					if variant != "no_ui_refresh" and (mode == "campaign" or frame % 9 == 0):
						var start := Time.get_ticks_usec()
						if mode == "campaign": app.campaign.refresh()
						else: app.update_hud()
						refresh_samples.append((Time.get_ticks_usec() - start) / 1000.0)
					var maintenance := Time.get_ticks_usec()
					field._process(1.0 / 60.0)
					maintenance_samples.append((Time.get_ticks_usec() - maintenance) / 1000.0)
					field.update_view(1.0 / 60.0, float(frame % 3) / 60.0)
				await RenderingServer.frame_post_draw
				Probe.enabled = false
				var row := {"mode": mode, "variant": variant, "repeat": repeat, "frame_ms": F.stats(samples),
					"tick_ms": F.stats(tick_samples), "refresh_ms": F.stats(refresh_samples), "view_maintenance_ms": F.stats(maintenance_samples),
					"counts": F.counts(game), "checksum": F.checksum(game), "profile": Probe.report()}
				rows.append(row)
				print("UI ", mode, " ", variant, " ", repeat, " ", row.frame_ms, " REFRESH ", row.refresh_ms)
				if repeat == 0 and variant == "full": root.get_texture().get_image().save_png(OS.get_environment("PERF_CAPTURE") + "/app_" + mode + "_390.png")
				app.free()
				await settle()
	var output := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
