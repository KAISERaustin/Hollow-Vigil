extends RefCounted

static func run(tree: SceneTree) -> int:
	tree.root.content_scale_size = Vector2i(720, 720)
	tree.root.size = Vector2i(720, 720)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(720, 720)
	backdrop.color = Color("10141c")
	tree.root.add_child(backdrop)
	var layer := VigilTerrainLayer.new()
	tree.root.add_child(layer)
	var cases := 0
	var samples := 0
	var failures := 0
	for style in VigilWorld.STYLES:
		for shape in ["single", "horizontal", "elbow"]:
			var game := VigilState.new(879)
			game.data.balance = 1e12
			if shape != "single":
				game.expand("1,0")
			if shape == "elbow":
				game.expand("0,1")
			for r in game.data.regions.values():
				r.style = style
			game.refresh_paths()
			for zoom in [0.42, 0.65, 1.0, 1.65]:
				cases += 1
				var camera := Vector2(0.37, -0.61) if shape == "single" else Vector2(149.37, 148.61)
				layer.synchronize(game, camera, zoom, Vector2(720, 720))
				await tree.process_frame
				await tree.process_frame
				await RenderingServer.frame_post_draw
				var rendered := tree.root.get_texture().get_image()
				var clean := true
				for id in game.data.regions:
					for direction in VigilWorld.DIRS:
						var neighbor := VigilWorld.key(VigilWorld.coord(id) + direction)
						var outward := Vector2(direction)
						var tangent := Vector2(-outward.y, outward.x)
						for t in range(-140, 141, 4):
							var world := VigilWorld.center(id) + outward * 150 + tangent * t
							var screen: Vector2 = (world - camera) * zoom + Vector2(360,360)
							# Check terrain clipping beyond the centered grid stroke.
							var clearance := ceili(layer.grid.LINE_WIDTH * zoom * 0.5) + 2
							for offset in [-clearance, clearance]:
								var point := Vector2i(screen + outward * offset)
								if point.x < 2 or point.y < 2 or point.x >= 718 or point.y >= 718:
									continue
								var should_be_blank: bool = offset > 0 and not game.data.regions.has(neighbor)
								var actual := rendered.get_pixelv(point)
								var blank := absf(actual.r - backdrop.color.r) < 0.004 and absf(actual.g - backdrop.color.g) < 0.004 and absf(actual.b - backdrop.color.b) < 0.004
								samples += 1
								if blank != should_be_blank:
									clean = false
				if not clean:
					failures += 1
					if failures == 1:
						rendered.save_png("res://.runtime/terrain-boundary-diagnostic.png")
						push_error("Terrain outer clipping or road join failed: %s %s %.2f" % [style, shape, zoom])
	var report := "TERRAIN BOUNDARIES: %d biome/shape/zoom cases, %d pixel samples, %d failures (fractional camera offsets)\n" % [cases, samples, failures]
	print(report)
	var file := FileAccess.open("res://artifacts/terrain-edge-results.txt", FileAccess.WRITE)
	file.store_string(report)
	failures += await check_grid(tree, layer, backdrop)
	layer.free()
	backdrop.free()
	return failures

static func check_grid(tree: SceneTree, layer: VigilTerrainLayer, backdrop: ColorRect) -> int:
	var game := VigilState.new(879)
	game.data.balance = 1e12
	var cases := 0
	var samples := 0
	var failures := 0
	# Reuse one layer across expansion, resizing, and distant camera moves.
	for expanded in [false, true]:
		if expanded:
			for id in ["-1,0", "1,0", "0,1", "-2,0"]:
				game.expand(id)
		for viewport in [Vector2i(720, 720), Vector2i(420, 800)]:
			tree.root.content_scale_size = viewport
			tree.root.size = viewport
			backdrop.size = Vector2(viewport)
			for camera in [Vector2(149.37, 148.61), Vector2(-450.37, -749.61), Vector2(300000.37, -300000.61)]:
				for zoom in [0.42, 0.65, 1.0, 1.65]:
					cases += 1
					layer.synchronize(game, camera, zoom, Vector2(viewport))
					await tree.process_frame
					await tree.process_frame
					await RenderingServer.frame_post_draw
					var rendered := tree.root.get_texture().get_image()
					var clean := true
					for y in range(5, viewport.y - 5, 9):
						for x in range(5, viewport.x - 5, 9):
							var world: Vector2 = (Vector2(x + 0.5, y + 0.5) - Vector2(viewport) * 0.5) / zoom + camera
							var cell: Vector2 = (world + Vector2.ONE * Balance.TILE * 0.5) / Balance.TILE
							var dx := absf(cell.x - roundf(cell.x)) * Balance.TILE
							var dy := absf(cell.y - roundf(cell.y)) * Balance.TILE
							var distance := minf(dx, dy)
							var expected := VigilTerrainArt.INK
							if distance > layer.grid.LINE_WIDTH * 0.5 - 1.0 / zoom:
								# Ignore rasterization at stroke edges and artwork inside
								# owned cells; empty cell interiors must stay untouched.
								if distance < layer.grid.LINE_WIDTH * 0.5 + 1.0 / zoom or game.data.regions.has(VigilWorld.key(Vector2i(floor(cell.x), floor(cell.y)))):
									continue
								expected = backdrop.color
							var actual := rendered.get_pixel(x, y)
							samples += 1
							if maxf(absf(actual.r - expected.r), maxf(absf(actual.g - expected.g), absf(actual.b - expected.b))) > 0.035:
								clean = false
					if not clean:
						failures += 1
						if failures == 1:
							rendered.save_png("res://.runtime/grid-diagnostic.png")
							push_error("World grid failed: expanded=%s viewport=%s camera=%s zoom=%.2f" % [expanded, viewport, camera, zoom])
	var report := "WORLD GRID: %d expansion/viewport/camera/zoom cases, %d pixel samples, %d failures\n" % [cases, samples, failures]
	print(report)
	FileAccess.open("res://artifacts/terrain-grid-results.txt", FileAccess.WRITE).store_string(report)
	return failures
