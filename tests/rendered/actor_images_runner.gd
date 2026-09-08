extends SceneTree

const Images = preload("res://scripts/rendering/actors/actor_images.gd")
const Baker = preload("res://tools/bake_actor_images.gd")

class ImageSheet extends Node2D:
	var images := Images.new()
	func _draw() -> void:
		for entry in Images.recipes():
			var at: Vector2 = entry.region.position - entry.bounds.position * Images.SCALE
			images.draw(self, entry.key, at, Images.SCALE)

func _initialize() -> void:
	call_deferred("run")

func capture(sheet: Node2D) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Images.SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	viewport.add_child(sheet)
	root.add_child(viewport)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.free()
	return image

func run() -> void:
	var source := await capture(Baker.Sheet.new())
	var rendered := await capture(ImageSheet.new())
	source.save_png("res://artifacts/actor-images-native.png")
	rendered.save_png("res://artifacts/actor-images-cached.png")
	var failures := 0
	var rows := []
	var total_bytes := 0
	var registry := Images.new()
	for entry in Images.recipes():
		var before := source.get_region(Rect2i(entry.region))
		var after := rendered.get_region(Rect2i(entry.region))
		var pixels := 0
		var error := 0.0
		for y in range(before.get_height()):
			for x in range(before.get_width()):
				var a := before.get_pixel(x,y)
				var b := after.get_pixel(x,y)
				if a.a == 0.0 and b.a == 0.0: continue
				pixels += 1
				error += absf(a.r*a.a-b.r*b.a) + absf(a.g*a.a-b.g*b.a) + absf(a.b*a.a-b.b*b.a) + absf(a.a-b.a)
		var mean_error := error / maxf(1.0, pixels * 4.0)
		var matches := pixels > 0 and mean_error < 0.025 and before.get_used_rect() == after.get_used_rect()
		if not matches: failures += 1
		var texture: Texture2D = load(registry.entries[entry.key].image)
		total_bytes += texture.get_image().get_data_size()
		rows.append({"artwork": entry.key, "mean_premultiplied_error": mean_error, "matches": matches})
	var file := FileAccess.open("res://docs/performance/2026-09-08-implementation/artwork_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "failures": failures, "texture_bytes_with_mipmaps": total_bytes}, "\t"))
	print("ACTOR IMAGES: ", rows.size(), " individual images, ", failures, " failures, bytes=", total_bytes)
	quit(1 if failures else 0)
