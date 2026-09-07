extends SceneTree

const Art = preload("res://scripts/rendering/actors/relic_art.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Palette = preload("res://scripts/rendering/terrain/terrain_art.gd")
var checks := 0
var failures: Array[String] = []

class Portrait extends Node2D:
	var kind := ""
	var extent := 256.0
	func _draw() -> void:
		Art.draw(self, kind, Vector2.ONE * extent * 0.5, extent / 32.0)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func portrait(kind: String, extent: int) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i.ONE * extent
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var sample := Portrait.new()
	sample.kind = kind
	sample.extent = extent
	view.add_child(sample)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := view.get_texture().get_image()
	view.free()
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/gear")
	var signatures := {}
	for kind in Relics.DEFINITIONS:
		var img := await portrait(kind, 256)
		check(img.save_png("res://assets/gear/" + kind + ".png") == OK, "Exports transparent native gear: " + kind)
		var used := img.get_used_rect()
		check(used.position.x >= 7 and used.position.y >= 7 and used.end.x <= 249 and used.end.y <= 249, "Artwork has transparent padding: " + kind)
		var signature := img.get_data().hex_encode().sha256_text()
		check(not signatures.has(signature), "Every gear illustration is unique: " + kind)
		signatures[signature] = kind
		var ink := 0
		var colors := {}
		for y in range(256):
			for x in range(256):
				var pixel := img.get_pixel(x, y)
				if pixel.a > 0.99:
					colors[pixel.to_html()] = true
					if pixel.r + pixel.g + pixel.b < 0.05: ink += 1
		check(ink > 150 and colors.size() >= 5, "Layered color materials and solid black outlines: " + kind)
		for extent in [24, 40, 64]:
			var small := await portrait(kind, extent)
			check(small.get_used_rect().size.x >= extent * 0.4 and small.get_used_rect().size.y >= extent * 0.6, "Silhouette remains visible at gameplay/portrait scale: " + kind + "/" + str(extent))
	await board()
	print("GEAR_ART: %d checks, %d failures; eighteen native exports and the gear board" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func board() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1080, 1190)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var canvas := Node2D.new()
	view.add_child(canvas)
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0, 0, 1080, 1190), Palette.PAPER)
		var font := ThemeDB.fallback_font
		canvas.draw_string(font, Vector2(38, 46), "HOLLOW VIGIL  /  BOSS GEAR", HORIZONTAL_ALIGNMENT_LEFT, 1000, 30, Palette.INK)
		canvas.draw_string(font, Vector2(38, 76), "18 relics · carved wood, weathered stone, iron, cloth and glass", HORIZONTAL_ALIGNMENT_LEFT, 1000, 17, Palette.BACKDROP)
		canvas.draw_line(Vector2(38, 92), Vector2(1042, 92), Palette.INK, 3)
		var row := 0
		for boss in Relics.BOSS_DROPS:
			var y := 120 + row * 174
			canvas.draw_string(font, Vector2(38, y + 7), Balance.BOSSES[boss].name, HORIZONTAL_ALIGNMENT_LEFT, 1000, 17, Palette.BACKDROP)
			for column in range(3):
				var kind: String = Relics.BOSS_DROPS[boss][column]
				var x := 190 + column * 350
				Art.draw(canvas, kind, Vector2(x, y + 76), 4.2)
				canvas.draw_string(font, Vector2(x - 160, y + 153), Relics.DEFINITIONS[kind].name, HORIZONTAL_ALIGNMENT_CENTER, 320, 19, Palette.INK)
			if row < 5:
				canvas.draw_line(Vector2(38, y + 166), Vector2(1042, y + 166), Color("bdb395"), 1)
			row += 1
	)
	await process_frame
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	check(img.save_png("res://artifacts/gear-lineup.png") == OK, "Exports complete labeled gear board")
	view.free()
