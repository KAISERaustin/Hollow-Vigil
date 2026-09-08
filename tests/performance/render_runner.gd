extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")
const Probe = preload("res://tests/performance/probe.gd")
const Field = preload("res://tests/performance/render_field.gd")
const Board = preload("res://tests/performance/render_board.gd")
var rows := []
var gpu_available := false

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 8) -> void:
	for frame in range(frames):
		await process_frame
		await RenderingServer.frame_post_draw

func sample(field, name: String, camera_mode: String, variant: String, repeat: int, live: bool = false) -> void:
	field.actor_mode = "markers" if variant == "markers" else ("none" if variant == "no_actors" else "full")
	field.omit_map = variant == "no_map"
	if field is Board: field.landscape.visible = not field.omit_map
	else: field.terrain_layer.visible = not field.omit_map
	var original_effects: Array[Dictionary] = field.state.combat.effects
	if variant == "no_cosmetics": field.state.combat.effects = []
	field.zoom = field.minimum_zoom() if camera_mode == "overview" else 1.0
	field.camera = field.trail_bounds.get_center() if field is Board else Vector2.ZERO
	if camera_mode == "offscreen": field.camera += Vector2(0, 4 * Balance.TILE)
	var base_camera: Vector2 = field.camera
	field.queue_redraw()
	await settle(20)
	Probe.reset()
	Probe.enabled = true
	var frame_samples := []
	var ticks := []
	var draw_calls := []
	var primitives := []
	var visible_enemies := []
	var cpu_render := []
	var gpu_render := []
	var drawn_frame_gaps := []
	var last_drawn := Engine.get_frames_drawn()
	var last := Time.get_ticks_usec()
	var before := F.counts(field.state)
	for frame in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		if frame > 0:
			frame_samples.append((now - last) / 1000.0)
			drawn_frame_gaps.append(Engine.get_frames_drawn() - last_drawn)
		last = now
		last_drawn = Engine.get_frames_drawn()
		if live and frame % 3 == 0:
			var start := Time.get_ticks_usec()
			field.state.combat.tick(Balance.STEP)
			ticks.append((Time.get_ticks_usec() - start) / 1000.0)
		if camera_mode == "pan": field.camera = base_camera + Vector2(sin(frame / 180.0 * TAU) * 4.0 * Balance.TILE, 0)
		field.update_view(1.0 / 60.0, float(frame % 3) / 60.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		# Query after the timed interval. It does add harness work to the next frame.
		var rect := Rect2(field.world(Vector2(-100, -100)), (field.size + Vector2(200, 200)) / field.zoom)
		visible_enemies.append(field.state.combat.visible_enemies(rect).size())
		if gpu_available:
			cpu_render.append(RenderingServer.call("viewport_get_measured_render_time_cpu", root.get_viewport_rid()))
			gpu_render.append(RenderingServer.call("viewport_get_measured_render_time_gpu", root.get_viewport_rid()))
	await RenderingServer.frame_post_draw
	Probe.enabled = false
	var row := {"case": name, "viewport": [root.size.x, root.size.y], "camera": camera_mode, "variant": variant,
		"repeat": repeat, "live": live, "zoom": field.zoom, "before": before, "after": F.counts(field.state),
		"frame_ms": F.stats(frame_samples), "samples_ms": frame_samples, "tick_ms": F.stats(ticks),
		"draw_calls": F.stats(draw_calls), "primitives": F.stats(primitives), "visible_enemies": F.stats(visible_enemies),
		"renderer_cpu_ms": F.stats(cpu_render), "renderer_gpu_ms": F.stats(gpu_render),
		"drawn_frame_gaps": F.stats(drawn_frame_gaps),
		"profile": Probe.report(), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	rows.append(row)
	var checkpoint := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	checkpoint.store_string(JSON.stringify({"partial": true, "rows": rows}, "\t"))
	checkpoint.close()
	print("RENDER ", name, " ", root.size, " ", camera_mode, " ", variant, " ", repeat, " ", row.frame_ms)
	if repeat == 0 and variant == "full" and camera_mode in ["close", "overview"] and not live:
		root.get_texture().get_image().save_png(OS.get_environment("PERF_CAPTURE") + "/" + name + "_" + str(root.size.x) + "_" + camera_mode + ".png")
	field.state.combat.effects = original_effects

func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for method in RenderingServer.get_method_list():
		if "measur" in str(method.name) or "timestamp" in str(method.name): print("RENDER_API ", method.name)
	gpu_available = RenderingServer.has_method("viewport_get_measured_render_time_gpu")
	if gpu_available: RenderingServer.call("viewport_set_measure_render_time", root.get_viewport_rid(), true)
	var environment := {"engine": Engine.get_version_info(), "adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(), "renderer": RenderingServer.get_current_rendering_method(),
		"gpu_timing_api": gpu_available, "vsync": DisplayServer.window_get_vsync_mode()}
	for mode in ["infinite", "campaign"]:
		var field
		if mode == "infinite":
			field = Field.new()
			field.state = F.infinite(4, true, true)
			for step in range(600): field.state.combat.tick(Balance.STEP)
		else:
			field = Board.new()
			field.run = F.campaign()
			F.populate_campaign(field.run, 500)
		root.add_child(field)
		field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		field.set_process(false)
		var viewports := [Vector2i(390,844)] if OS.get_environment("PERF_INSTRUMENTED") == "1" else [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]
		var repeats := 1 if OS.get_environment("PERF_INSTRUMENTED") == "1" else 3
		for viewport in viewports:
			root.size = viewport
			root.content_scale_size = viewport
			await settle()
			for camera_mode in ["close", "overview", "offscreen", "pan"]:
				for repeat in range(repeats): await sample(field, mode, camera_mode, "full", repeat)
			if viewport.x == 390:
				for variant in ["no_actors", "markers", "no_map", "no_cosmetics"]:
					for repeat in range(repeats): await sample(field, mode, "overview", variant, repeat)
		field.free()
		await settle()
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"environment": environment, "rows": rows}, "\t"))
	quit()
