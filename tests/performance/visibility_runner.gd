extends "res://tests/performance/render_runner.gd"

func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(390,844)
	root.content_scale_size = root.size
	gpu_available = RenderingServer.has_method("viewport_get_measured_render_time_gpu")
	if gpu_available: RenderingServer.call("viewport_set_measure_render_time", root.get_viewport_rid(), true)
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
		for repeat in range(3): await sample(field, mode, "hidden", "full", repeat)
		for repeat in range(3): await sample(field, mode, "overview", "no_cosmetics", repeat)
		field.free()
		await settle()
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
