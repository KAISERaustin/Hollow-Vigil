extends SceneTree

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var progress := preload("res://scripts/campaign/progress.gd").new()
	for width in [360,390,540]:
		root.size = Vector2i(width,900)
		root.content_scale_size = root.size
		for completed in [1,20]:
			progress.data.completed_levels = completed
			var map := preload("res://scripts/campaign/world_map.gd").new()
			map.progress = progress
			root.add_child(map)
			map.size.x = width
			map.arrange()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/cleared-map-%d-%d.png" % [width,completed])
			map.queue_free()
			await process_frame
	print("CLEARED MAP: rendered ordinary and boss victories at 360, 390 and 540 pixels")
	quit()
