extends SceneTree

const Images = preload("res://scripts/rendering/actors/actor_images.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
const STAGES = [[1, "", "tier-1"], [2, "", "tier-2"], [3, "", "tier-3"],
	[4, "scatterworks", "tier-4-broadscatter"], [4, "dreadjaw", "tier-4-ironthorn"]]
var failures: Array[String] = []
var checks := 0

class SpriteCheck extends Node2D:
	var stage: Array = STAGES[0]
	var zoom := 1.0
	var mode := "runtime"
	func _draw() -> void:
		var at := Vector2(128, 232)
		if mode == "direct":
			var images = Images.for_canvas(self)
			var entry: Dictionary = images.entries["tower/caltrop_keep/%d/%s" % [stage[0], stage[1]]]
			var b: Array = entry.bounds
			draw_texture_rect(Images.texture_for(entry), Rect2(at + Vector2(b[0], b[1]) * zoom,
				Vector2(b[2], b[3]) * zoom), false)
		elif mode == "export":
			VigilTerrainArt.sentinel_vector(self, "caltrop_keep", at, zoom, stage[0], stage[1])
		else:
			VigilTerrainArt.sentinel(self, "caltrop_keep", at, zoom, stage[0], stage[1])

class Board extends Battlefield:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("293633"))
		for tower in state.data.towers.values():
			var at := screen(VigilWorld.pad_position(tower.region, tower.pad))
			draw_line(at + Vector2(-32, 1), at + Vector2(32, 1), Color("758f9e"), 1)
			draw_tower(tower)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var images := Images.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := SpriteCheck.new()
	viewport.add_child(art)
	var previous := PackedByteArray()
	for stage in STAGES:
		var key := "tower/caltrop_keep/%d/%s" % [stage[0], stage[1]]
		var entry: Dictionary = images.entries[key]
		var source := "res://docs/concepts/caltrop-keep-2026-09-20/%s.png" % stage[2]
		check(FileAccess.get_sha256(entry.image) == FileAccess.get_sha256(source), key + " approved source unchanged")
		check(entry.authored and not entry.has("native_fallback_above_zoom"), key + " authored at every zoom and protected from rebaking")
		var texture: Texture2D = Images.texture_for(entry)
		check(texture.get_size() == Vector2(1254, 1254), key + " complete source canvas")
		var b: Array = entry.bounds
		var origin := Vector2(b[0], b[1])
		check((origin + Vector2(627, 1122) / entry.pixels_per_unit).is_zero_approx(), key + " shared ground anchor")
		var picture := texture.get_image()
		check(is_equal_approx(float(entry.pixels_per_unit), 20.0), key + " shared battlefield scale")
		var p: Array = entry.portrait_bounds
		var visible := picture.get_used_rect()
		var visible_world := Rect2(origin + Vector2(visible.position) / entry.pixels_per_unit,
			Vector2(visible.size) / entry.pixels_per_unit)
		check(Rect2(p[0], p[1], p[2], p[3]).encloses(visible_world), key + " portrait includes complete silhouette")
		art.stage = stage
		for zoom in [1.0, 3.0]:
			art.zoom = zoom
			art.mode = "direct"
			art.queue_redraw()
			await frame()
			var expected := viewport.get_texture().get_image().get_data()
			for mode in ["runtime", "export"]:
				art.mode = mode
				art.queue_redraw()
				await frame()
				var rendered := viewport.get_texture().get_image()
				check(rendered.get_data() == expected, "%s %s zoom %.1f uses authored image" % [key, mode, zoom])
				check(Rect2i(0, 0, 256, 256).encloses(rendered.get_used_rect().grow(3)), key + " unclipped sprite")
			if zoom == 3.0:
				check(expected != previous, key + " distinct upgrade silhouette")
				previous = expected
	art.free()
	for stage in STAGES:
		for dimension in [48, 80]:
			viewport.size = Vector2i(dimension, dimension)
			var portrait := Portrait.preview("towers", "caltrop_keep", stage[0], stage[1])
			# Compact tower dialogs use the same draw helper without row minimums.
			portrait.custom_minimum_size = Vector2.ZERO
			portrait.size = Vector2.ONE * dimension
			viewport.add_child(portrait)
			await frame()
			var used := viewport.get_texture().get_image().get_used_rect()
			check(used.has_area() and Rect2i(1, 1, dimension - 2, dimension - 2).encloses(used),
				"%s portrait fits %d pixels" % [stage[2], dimension])
			portrait.free()
	viewport.free()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var board := Board.new()
		board.state = VigilState.new(513)
		board.state.data.towers.clear()
		board.size = dimensions
		board.zoom = 1.25
		board.unrestricted_camera = true
		root.add_child(board)
		board.set_process(false)
		for index in range(STAGES.size()):
			var stage: Array = STAGES[index]
			var at := Vector2(dimensions.x * 0.27, 130 + index * 105)
			var location := VigilWorld.ground_location(board.world(at))
			var id := str(index)
			board.state.data.towers[id] = {"id": id, "kind": "caltrop_keep", "level": stage[0],
				"branch": stage[1], "region": location.region, "pad": location.pad, "angle": 0.0, "earnings": 0.0}
			var portrait := Portrait.preview("towers", "caltrop_keep", stage[0], stage[1])
			portrait.position = Vector2(dimensions.x * 0.65 - 40, 47 + index * 105)
			portrait.size = Vector2(80, 80)
			board.add_child(portrait)
			var label := Label.new()
			label.text = "Caltrop Keep %d" % stage[0] if stage[1] == "" else Balance.BRANCHES.caltrop_keep[stage[1]].name
			label.position = Vector2(dimensions.x * 0.52, 130 + index * 105)
			label.add_theme_font_size_override("font_size", 13)
			board.add_child(label)
		board.queue_redraw()
		await frame()
		check(root.get_texture().get_image().save_png("res://artifacts/caltrop-keep-%dx%d.png" % [dimensions.x, dimensions.y]) == OK, "Saved battlefield and portrait capture")
		board.free()
	print("CALTROP KEEP: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
