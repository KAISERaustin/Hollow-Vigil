extends "res://tests/performance/render_runner.gd"

## Diagnostic only: measure per-region raster caching against retained native
## terrain commands. No production cache policy is changed by this experiment.
class BakedTile extends VigilTerrainTile:
	var picture: Texture2D
	func _draw() -> void:
		if picture != null: draw_texture_rect(picture, Rect2(Vector2.ZERO, size), false)

func bake_tiles(parent: Node, field) -> int:
	var bytes := 0
	for child in parent.get_children():
		if not child is VigilTerrainTile: continue
		var original: VigilTerrainTile = child
		var tile := BakedTile.new()
		tile.region = original.region
		tile.position = original.position
		tile.size = original.size
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var index := original.get_index()
		parent.remove_child(original)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(600, 600)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		original.position = Vector2.ZERO
		original.scale = Vector2.ONE * 2.0
		viewport.add_child(original)
		root.add_child(viewport)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := viewport.get_texture().get_image()
		picture.generate_mipmaps()
		bytes += picture.get_data_size()
		tile.picture = ImageTexture.create_from_image(picture)
		parent.add_child(tile)
		parent.move_child(tile, index)
		if parent == field.terrain_layer:
			field.terrain_layer.chunks[tile.region.id] = tile
		viewport.free()
	return bytes

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
			field = Field.new(); field.state = F.infinite(4, true, true)
			for step in range(600): field.state.combat.tick(Balance.STEP)
		else:
			field = Board.new(); field.run = F.campaign(); F.populate_campaign(field.run, 500)
		root.add_child(field)
		field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		field.set_process(false)
		await settle()
		for repeat in range(3): await sample(field, mode + "_terrain_vectors", "overview", "full", repeat)
		var started := Time.get_ticks_usec()
		var bytes := await bake_tiles(field.terrain_layer if mode == "infinite" else field.landscape, field)
		var bake_ms := (Time.get_ticks_usec() - started) / 1000.0
		for repeat in range(3):
			await sample(field, mode + "_terrain_images", "overview", "full", repeat)
			rows[-1]["terrain_image_bytes"] = bytes
			rows[-1]["initial_bake_ms"] = bake_ms
		field.free()
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
