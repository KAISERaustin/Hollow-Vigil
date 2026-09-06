extends SceneTree

# Manual acceptance session: real UI, HTTP, and gameplay; separate local saves.
# No account tokens are written to disk. Relaunch to resume the QA save slots.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session_title := OS.get_environment("HOLLOW_QA_TITLE")
	if not session_title.is_empty(): root.title = session_title
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

	# Sign in only after the first visible frame. A manual retry stays available
	# if networking fails, without granting any permissions or bypassing Auth.
	await RenderingServer.frame_post_draw
	if OS.get_environment("HOLLOW_QA_AUTO_SIGN_IN") == "1":
		await authenticate(app)
	var sign_in := Button.new()
	sign_in.text = "Sign in to QA account"
	sign_in.position = Vector2(24, 24)
	sign_in.size = Vector2(260, 48)
	app.add_child(sign_in)
	if app.cloud.signed_in(): sign_in.hide()
	sign_in.pressed.connect(func():
		sign_in.disabled = true
		await authenticate(app)
		sign_in.disabled = false
		if app.cloud.signed_in(): sign_in.hide()
	)

func authenticate(app: VigilApp) -> void:
	var address := OS.get_environment("HOLLOW_QA_EMAIL")
	var password := OS.get_environment("HOLLOW_QA_PASSWORD")
	if not address.is_empty() and not password.is_empty():
		app.cloud.busy = true
		var result: Dictionary = await app.cloud._request("/auth/v1/token?grant_type=password", {"email": address, "password": password}, false)
		password = ""
		app.cloud.busy = false
		if result.ok and app.cloud._accept_session(result.data):
			OS.set_environment("HOLLOW_QA_PASSWORD", "")
			app.cloud.email = address
			await app.cloud.refresh_worlds()
			print("QA account authenticated through Supabase Auth")
		else:
			app.cloud._say("QA sign-in failed. Retry the QA sign-in button when online.")
			print("QA sign-in failed: HTTP %s" % result.code)
