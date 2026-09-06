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

	var address := OS.get_environment("HOLLOW_QA_EMAIL")
	var password := OS.get_environment("HOLLOW_QA_PASSWORD")
	OS.set_environment("HOLLOW_QA_PASSWORD", "")
	if not address.is_empty() and not password.is_empty():
		app.cloud.busy = true
		var result: Dictionary = await app.cloud._request("/auth/v1/token?grant_type=password", {"email": address, "password": password}, false)
		password = ""
		app.cloud.busy = false
		if result.ok and app.cloud._accept_session(result.data):
			app.cloud.email = address
			await app.cloud.refresh_worlds()
			print("QA account authenticated through Supabase Auth")
		else:
			app.cloud._say("QA sign-in failed. Check the local QA account configuration.")
			push_error("QA sign-in failed: HTTP %s" % result.code)
