extends SceneTree

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://smoke.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# These layout fixtures intentionally pan/zoom outside playable camera bounds.
	# The production limits are exercised separately by camera_limits_runner.gd.
	app.field.set_unrestricted_camera(true)
	await preload("res://tests/rendered/visual_smoke.gd").run(app)
