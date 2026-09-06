extends SceneTree

# Manual acceptance session: real UI, HTTP, and gameplay; separate local saves.
# No account tokens are written to disk. Relaunch to resume the QA save slots.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://cloud-acceptance-placeholder.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.cloud.enabled = true
	app.public_builds.set_process(true)
	app.show_save_slots()
	app.slot_active = false
	app.slot_menu.slots.base_path = "user://cloud-acceptance"
	app.slot_menu.show_slots()
