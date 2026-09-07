extends SceneTree
## Compare textured edges against Godot's native rounded silhouette on the GPU.

const UI = preload("res://scripts/ui/shared/interface.gd")
var checks := 0
var failures: Array[String] = []

class Sample extends Node2D:
	var style: StyleBox
	var bounds := Rect2(16, 16, 221, 77)
	var factor := 1.0
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * factor)
		draw_style_box(style, bounds)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 120)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func run() -> void:
	var actual_view := make_viewport()
	var reference_view := make_viewport()
	var actual := Sample.new()
	var reference := Sample.new()
	actual_view.add_child(actual)
	reference_view.add_child(reference)
	for color in [UI.PANEL, UI.SURFACE, UI.GOLD, UI.DANGER]:
		for width in [1, 2, 3, 4]:
			for radius in [0, 4]:
				actual.style = UI.surface(color, width, 0)
				actual.style.set_corner_radius_all(radius)
				var silhouette := StyleBoxFlat.new()
				silhouette.bg_color = Color.BLACK
				silhouette.border_color = Color.BLACK
				silhouette.set_border_width_all(width)
				silhouette.set_corner_radius_all(radius)
				reference.style = silhouette
				for factor in [0.75, 1.0, 1.25, 1.5, 2.0]:
					for offset in [Vector2.ZERO, Vector2(0.25, 0.5)]:
						actual.factor = factor
						reference.factor = factor
						actual.bounds.position = Vector2(16, 16) + offset
						reference.bounds = actual.bounds
						actual.queue_redraw()
						reference.queue_redraw()
						await process_frame
						await RenderingServer.frame_post_draw
						var rendered := actual_view.get_texture().get_image()
						var expected := reference_view.get_texture().get_image()
						var bleed := 0
						var gaps := 0
						var bounds := Rect2(actual.bounds.position * factor, actual.bounds.size * factor)
						for y in range(floori(bounds.position.y) - 2, ceili(bounds.end.y) + 2):
							for x in range(floori(bounds.position.x) - 2, ceili(bounds.end.x) + 2):
								var pixel := rendered.get_pixel(x, y)
								var target := expected.get_pixel(x, y)
								# Only ink may contribute to the outer antialiased edge.
								if target.a < 0.99 and (maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.01 or absf(pixel.a - target.a) > 0.01):
									bleed += 1
								if target.a >= 0.99 and pixel.a < 0.99:
									gaps += 1
						var context := "%s border %d radius %d scale %.2f offset %s" % [color, width, radius, factor, offset]
						check(bleed == 0, "%d parchment pixels outside the solid rim: %s" % [bleed, context])
						check(gaps == 0, "%d transparent seams inside the panel: %s" % [gaps, context])
						var center := rendered.get_pixelv(Vector2i(bounds.get_center()))
						check(center.a == 1.0 and center.r > 0.4, "Parchment remains visible: " + context)
						if color == UI.PANEL and width == 4 and radius == 4 and factor == 1.0 and offset == Vector2.ZERO:
							rendered.save_png("res://artifacts/parchment-corner-sample.png")
	actual_view.free()
	reference_view.free()
	print("PARCHMENT_CORNERS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
