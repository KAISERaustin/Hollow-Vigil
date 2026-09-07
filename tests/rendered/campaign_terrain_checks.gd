extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	for viewport_size in [Vector2i(360, 480), Vector2i(390, 530), Vector2i(540, 720)]:
		await check_levels(viewport_size)
	print("Campaign terrain: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_levels(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	root.content_scale_size = root.size
	for index in range(20):
		var board := preload("res://scripts/campaign/board.gd").new()
		board.run = preload("res://scripts/campaign/run.gd").new(index)
		board.size = Vector2(root.size)
		root.add_child(board)
		await frame()
		root.get_texture().get_image().save_png("res://artifacts/campaign-terrain-%02d-%d.png" % [index + 1, root.size.x])
		await check_roads(board, index)
		# Remove intentional ink (roads, props, sockets and actors), leaving the
		# actual tile geometry and clipping to expose any unintended ground seams.
		for tile in board.landscape.get_children():
			if not tile is VigilTerrainTile:
				tile.hide()
				continue
			tile.roads.clear()
			tile.scenery.clear()
			tile.ground_details.clear()
			tile.pads.clear()
			tile.queue_redraw()
		var ground := VigilTerrainArt.ground_color(board.run.mission.style)
		var landscape := board.landscape
		var underlay := board.get_child(0)
		underlay.reparent(root)
		landscape.reparent(root)
		board.hide()
		for factor in [1.0, 1.25, 1.73]:
			var scale_value: float = board.minimum_zoom() * factor
			landscape.scale = Vector2.ONE * scale_value
			landscape.position = board.size * 0.5 - (board.camera + Vector2(0.37, 0.61)) * scale_value
			await frame()
			var picture := root.get_texture().get_image()
			var bad := 0
			for y in range(2, picture.get_height() - 2):
				for x in range(2, picture.get_width() - 2):
					var pixel := picture.get_pixel(x, y)
					if absf(pixel.r - ground.r) + absf(pixel.g - ground.g) + absf(pixel.b - ground.b) > 0.04:
						bad += 1
			checks += 1
			if bad > 0:
				failures += 1
				print("Level %d zoom %.2f: %d seam pixels" % [index + 1, factor, bad])
		landscape.free()
		underlay.free()
		board.free()

func check_roads(board: Control, index: int) -> void:
	# Compare the actual tiled landscape with the authored roads drawn once.
	# Keep roads visible: a ground-only check cannot catch clipping inside roads.
	for tile in board.landscape.get_children():
		if tile is VigilTerrainTile:
			tile.scenery.clear()
			tile.ground_details.clear()
			tile.pads.clear()
			tile.queue_redraw()
	var landscape: Node2D = board.landscape
	var underlay: Node = board.get_child(0)
	underlay.reparent(root)
	landscape.reparent(root)
	board.hide()
	var reference := Node2D.new()
	root.add_child(reference)
	reference.draw.connect(func():
		for road in board.run.mission.routes:
			reference.draw_polyline(road, VigilTerrainArt.INK, 28.0, true)
		for road in board.run.mission.routes:
			reference.draw_polyline(road, VigilTerrainArt.ROAD, 23.0, true)
		for road in board.run.mission.routes:
			VigilTerrainArt.road_detail(reference, road)
	)
	for factor in [1.0, 1.25, 1.73, 3.0]:
		for offset in [Vector2(0.37, 0.61), Vector2(83.19, -117.43)]:
			landscape.scale = Vector2.ONE * board.minimum_zoom() * factor
			landscape.position = board.size * 0.5 - (board.camera + offset) * landscape.scale
			reference.transform = landscape.transform
			reference.hide()
			landscape.show()
			await frame()
			var actual := root.get_texture().get_image()
			landscape.hide()
			reference.show()
			reference.queue_redraw()
			await frame()
			var expected := root.get_texture().get_image()
			var bad := 0
			for y in range(2, actual.get_height() - 2):
				for x in range(2, actual.get_width() - 2):
					var a := actual.get_pixel(x, y)
					var b := expected.get_pixel(x, y)
					if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.04:
						bad += 1
			checks += 1
			if bad > 0:
				failures += 1
				print("Level %d width %d road zoom %.2f offset %s: %d incorrect pixels" % [index + 1, root.size.x, factor, offset, bad])
				if factor == 1.73 and offset.x < 1:
					actual.save_png("res://artifacts/campaign-road-before-%02d.png" % (index + 1))
	reference.free()
	landscape.show()
	underlay.reparent(board)
	board.move_child(underlay, 0)
	landscape.reparent(board)
	board.show()
