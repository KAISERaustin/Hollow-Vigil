extends SceneTree

## Run with a rendering-capable Godot executable, never --headless.
## All pixels come from the current native artwork; no replacement designs.
const Atlas = preload("res://scripts/rendering/actors/actor_images.gd")
const Expansion = preload("res://scripts/rendering/actors/expansion_tower_art.gd")

class Sheet extends Node2D:
	func _draw() -> void:
		for entry in Atlas.recipes():
			var at: Vector2 = entry.region.position - entry.bounds.position * Atlas.SCALE
			if entry.family == "enemy":
				VigilTerrainArt.enemy_vector(self, entry.kind, at, Atlas.SCALE)
			elif entry.kind == "ironspike":
				draw_set_transform(at, 0, Vector2.ONE * Atlas.SCALE)
				if entry.family == "bow": Expansion.ironspike_bow(self, entry.level, entry.branch)
				else: Expansion.ironspike_base(self, entry.level, entry.branch)
				draw_set_transform(Vector2.ZERO)
			else:
				VigilTerrainArt.sentinel_vector(self, entry.kind, at, Atlas.SCALE, entry.level, entry.branch)

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var viewport := SubViewport.new()
	viewport.size = Atlas.SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.add_child(Sheet.new())
	root.add_child(viewport)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	var catalog := {}
	var catalog_path := "res://assets/artwork/catalog.json"
	if FileAccess.file_exists(catalog_path): catalog = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	var overwrite := "--overwrite-native" in OS.get_cmdline_user_args()
	var status := OK
	for entry in Atlas.recipes():
		var path: String = "res://assets/artwork/" + entry.key.trim_suffix("/") + ".png"
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if overwrite or not FileAccess.file_exists(path):
			status = picture.get_region(Rect2i(entry.region)).save_png(path)
			if status != OK: break
		if not catalog.has(entry.key):
			catalog[entry.key] = {"image": path, "bounds": [entry.bounds.position.x, entry.bounds.position.y,
				entry.bounds.size.x, entry.bounds.size.y], "pixels_per_unit": Atlas.SCALE,
				"native_fallback_above_zoom": Atlas.SCALE}
	var file := FileAccess.open(catalog_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog, "\t"))
	file.close()
	print("ACTOR_IMAGES entries=", catalog.size(), " status=", status)
	viewport.free()
	quit(status)
