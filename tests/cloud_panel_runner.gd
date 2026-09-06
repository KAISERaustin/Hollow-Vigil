extends SceneTree

const UI = preload("res://scripts/ui/shared/interface.gd")

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	# Exercise the actual cloud panel without loading battlefield/audio assets.
	var app := VigilApp.new()
	app.cloud = preload("res://scripts/cloud/cloud_service.gd").new()
	app.cloud.game = app.game
	app.cloud.enabled = false
	root.add_child(app.cloud)
	app.cloud.email = "player@example.invalid"
	root.size = Vector2i(390, 844)
	RenderingServer.set_default_clear_color(UI.PANEL)
	var margin := MarginContainer.new()
	margin.theme = UI.theme()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var panel := preload("res://scripts/cloud/cloud_panel.gd").new()
	panel.app = app
	margin.add_child(panel)
	await process_frame
	await process_frame
	var code := panel.find_child("CloudSignInLink", true, false) as LineEdit
	if code == null or not code.secret or code.placeholder_text != "Email code or sign-in link" or code.get_global_rect().end.x > 390:
		push_error("Cloud code field is missing, unmasked, or outside the viewport")
		quit(1)
		return
	await process_frame
	root.get_texture().get_image().save_png("res://artifacts/cloud-code-panel.png")
	print("Cloud panel: masked code/link field fits 390 x 844")
	app.cloud.queue_free()
	margin.queue_free()
	app.free()
	await process_frame
	quit()
