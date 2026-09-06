extends SceneTree

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var app := preload("res://scripts/app/main.gd").new()
	app.load_saved_progress = false
	app.game.save_path = "user://cloud-ui-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2i(390,844)
	await process_frame
	await process_frame
	app.panels.show_cloud_saves()
	await process_frame
	await process_frame
	await process_frame
	var email := app.find_child("CloudEmail", true, false)
	if email == null:
		push_error("Cloud email field missing")
		quit(1)
		return
	print("Cloud screen ready; no upload without sign-in")
	app.cloud.email = "player@example.invalid"
	app.cloud.changed.emit()
	await process_frame
	await process_frame
	var code := app.find_child("CloudSignInLink", true, false) as LineEdit
	if code == null or not code.secret or code.placeholder_text != "Email code or sign-in link":
		push_error("Masked email code field missing")
		quit(1)
		return
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("res://artifacts/cloud-sign-in.png")
	app.cloud.player_id = "10000000-0000-4000-8000-000000000001"
	app.cloud.refresh_token = "synthetic"
	app.cloud.worlds = [{"world_id":"20000000-0000-4000-8000-000000000001","seed":42,"updated_at":"2026-09-06T12:00:00Z"}]
	app.cloud.changed.emit()
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://artifacts/cloud-worlds.png")
	app.queue_free()
	await process_frame
	quit()
