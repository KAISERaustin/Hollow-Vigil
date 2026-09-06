extends SceneTree

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://offscreen-portals.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var failures: Array[String] = []
	await preload("res://tests/rendered/offscreen_portal_checks.gd").run(app, failures)
	for failure in failures:
		push_error(failure)
	print("OFFSCREEN RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
