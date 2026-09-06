extends SceneTree

var failures: Array[String] = []
var samples := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func near_color(actual: Color, expected: Color) -> bool:
	return maxf(absf(actual.r - expected.r), maxf(absf(actual.g - expected.g), absf(actual.b - expected.b))) < 0.035

func check_pixel(rendered: Image, point: Vector2, expected: Color, label: String) -> void:
	samples += 1
	if not near_color(rendered.get_pixelv(Vector2i(point)), expected):
		if failures.size() < 20:
			failures.append(label + " at " + str(point))

func run() -> void:
	root.min_size = Vector2i.ZERO
	root.content_scale_size = Vector2i(720, 720)
	root.size = Vector2i(720, 720)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(720, 720)
	backdrop.color = VigilTerrainArt.BACKDROP
	root.add_child(backdrop)
	var layer := VigilTerrainLayer.new()
	root.add_child(layer)
	var cases := 0
	for first in VigilWorld.ALL_STYLES:
		for second in VigilWorld.ALL_STYLES:
			for direction in VigilWorld.DIRS:
				var game := VigilState.new(879)
				game.data.regions.clear()
				var origin := Vector2i(-2, -3)
				var id := VigilWorld.key(origin)
				var other := VigilWorld.key(origin + direction)
				game.data.regions[id] = VigilWorld.make_region(id, "", 879)
				game.data.regions[other] = VigilWorld.make_region(other, id, 879)
				game.data.regions[id].style = first
				game.data.regions[other].style = second
				game.refresh_paths()
				var outward := Vector2(direction)
				var tangent := Vector2(-outward.y, outward.x)
				var seam := VigilWorld.center(id) + outward * 150
				for zoom in [0.42, 0.65, 1.0, 1.65]:
					cases += 1
					var camera := seam + Vector2(0.37, -0.61)
					layer.synchronize(game, camera, zoom, Vector2(720, 720))
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					var rendered := root.get_texture().get_image()
					var label := "%s/%s %s zoom %.2f" % [first, second, direction, zoom]
					# The divider must continue along the ENTIRE shared edge,
					# including through the central road mouth and same-biome joins.
					for offset in range(-140, 141, 5):
						var point: Vector2 = (seam + tangent * offset - camera) * zoom + Vector2(360, 360)
						var darkest := 1.0
						for n in [-1, 0, 1]:
							var color := rendered.get_pixelv(Vector2i(point + outward * n))
							darkest = minf(darkest, maxf(color.r, maxf(color.g, color.b)))
						samples += 1
						if darkest > 0.035 and failures.size() < 20:
							failures.append("Missing black divider: " + label + " offset " + str(offset))
					# Both road mouths remain filled and aligned immediately either
					# side of the divider. Ground keeps its own flat biome color.
					for side in [-1, 1]:
						var world: Vector2 = seam + outward * side * 10
						check_pixel(rendered, (world - camera) * zoom + Vector2(360, 360), VigilTerrainArt.ROAD, "Road join: " + label)
						for offset in [-110, -55, 55, 110]:
							var point: Vector2 = (seam + outward * side * 7 + tangent * offset - camera) * zoom + Vector2(360, 360)
							check_pixel(rendered, point, VigilTerrainArt.ground_color(first if side < 0 else second), "Biome fill: " + label)
					if not failures.is_empty():
						rendered.save_png("res://artifacts/palette-diagnostic.png")
						break
	var report := "PALETTE TERRAIN: %d biome/direction/zoom cases, %d pixel checks, %d failures\n" % [cases, samples, failures.size()]
	for failure in failures:
		report += failure + "\n"
	print(report)
	FileAccess.open("res://artifacts/terrain-palette-results.txt", FileAccess.WRITE).store_string(report)
	layer.free()
	backdrop.free()
	var edge_failures: int = await preload("res://tests/rendered/terrain_edge_checks.gd").run(self)
	quit(0 if failures.is_empty() and edge_failures == 0 else 1)
