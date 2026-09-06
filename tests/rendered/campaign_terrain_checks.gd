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
	root.size = Vector2i(390, 530)
	root.content_scale_size = root.size
	for index in range(20):
		var board := preload("res://scripts/campaign/board.gd").new()
		board.run = preload("res://scripts/campaign/run.gd").new(index)
		board.size = Vector2(root.size)
		root.add_child(board)
		await frame()
		root.get_texture().get_image().save_png("res://artifacts/campaign-terrain-%02d.png" % (index + 1))
		# Remove intentional ink (roads, props, sockets and actors), leaving the
		# actual tile geometry and clipping to expose any unintended ground seams.
		for tile in board.landscape.get_children():
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
	print("Campaign terrain: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
