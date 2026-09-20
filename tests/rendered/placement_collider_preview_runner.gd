extends "res://tests/test_runner.gd"

func run() -> void:
	# This is a wide artwork authoring sheet, not an app/device viewport test.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 620)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := preload("res://scenes/tools/tower_placement_colliders.tscn").instantiate()
	viewport.add_child(preview)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(preview.get_child_count() == 8, "All eight editable tower previews")
	for child in preview.get_children():
		check(child.collider == Balance.Content.tower(child.tower_kind).placement_collider(), child.name + " preview uses actual runtime collider")
		check(child.artwork != null and child.collider.valid(), child.name + " has artwork and valid collider")
	check(viewport.get_texture().get_image().save_png("res://artifacts/tower-placement-colliders.png") == OK, "Saved collider authoring preview")
	viewport.free()
	print("COLLIDER PREVIEW: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
