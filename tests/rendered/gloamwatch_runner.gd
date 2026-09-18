extends SceneTree

const Images = preload("res://scripts/rendering/actors/actor_images.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
const Effects = preload("res://scripts/rendering/effects/attack_effects.gd")
const STAGES = [[1, ""], [2, ""], [3, ""], [4, "frostneedle"], [4, "thorn_volley"]]
var failures: Array[String] = []
var checks := 0

class Board extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("293633"))
		for i in range(5):
			var at := Vector2(size.x * 0.28, 110 + i * 105)
			var stage: Array = STAGES[i]
			VigilTerrainArt.sentinel(self, "rapid", at, 1.15, stage[0], stage[1])
			draw_line(at + Vector2(-27, 0), at + Vector2(27, 0), Color("758f9e"), 1)
			var stats := Balance.stats("rapid", stage[0], {}, stage[1])
			var fx := {"tower_kind": "rapid", "branch": stage[1], "color": stats.color,
				"flight": 0.2, "life": 0.26, "max_life": 0.29, "radius": 0.0}
			var origin: Vector2 = at + Balance.PROJECTILES.rapid.muzzle * 1.15
			Effects.draw(self, fx, origin, origin + Vector2(70, 15), 1.15)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var images := Images.new()
	check(Balance.TOWERS.rapid.name == "Gloamwatch", "Catalog name")
	check("watchman" in Balance.TOWERS.rapid.description, "Watchman lore")
	for stage in STAGES:
		var key := "tower/rapid/%d/%s" % [stage[0], stage[1]]
		var entry: Dictionary = images.entries[key]
		var b: Array = entry.bounds
		var texture: Texture2D = Images.texture_for(entry)
		check(texture.get_size() == Vector2(1024, 1536), key + " full canvas")
		check(not entry.has("native_fallback_above_zoom") and entry.authored, key + " authored at every zoom")
		var anchor: Vector2 = Vector2(b[0], b[1]) + Vector2(512, 1352) / entry.pixels_per_unit
		check(anchor.is_zero_approx(), key + " ground anchor")
		var muzzle_pixel: Vector2 = (Balance.PROJECTILES.rapid.muzzle - Vector2(b[0], b[1])) * entry.pixels_per_unit
		var pixel := texture.get_image().get_pixelv(Vector2i(muzzle_pixel))
		check(pixel.r < 0.01 and pixel.g < 0.01 and pixel.b < 0.01 and pixel.a > 0.9, key + " outlet inside black window")
		check(texture.get_image().get_pixel(100, 100).a == 0, key + " no background rectangle")
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var board := Board.new()
		board.size = dimensions
		root.add_child(board)
		for i in range(5):
			var stage: Array = STAGES[i]
			var portrait := Portrait.preview("towers", "rapid", stage[0], stage[1])
			portrait.position = Vector2(dimensions.x * 0.59, 35 + i * 105)
			portrait.size = Vector2(80, 80)
			board.add_child(portrait)
			var label := Label.new()
			label.text = "Gloamwatch %d" % stage[0] if stage[1] == "" else Balance.BRANCHES.rapid[stage[1]].name
			label.position = Vector2(dimensions.x * 0.55, 113 + i * 105)
			label.add_theme_font_size_override("font_size", 12)
			board.add_child(label)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/gloamwatch-%dx%d.png" % [dimensions.x, dimensions.y]) == OK, "Saved phone render")
		board.free()
	print("GLOAMWATCH: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
