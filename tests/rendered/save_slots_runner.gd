extends SceneTree

const Harness = preload("res://tests/rendered/visual_smoke.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://slots-ui-placeholder.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_save_slots()
	app.slot_active = false
	app.slot_menu.slots.base_path = "user://slots-ui-" + str(Time.get_ticks_usec())
	var slots: VigilSaveSlots = app.slot_menu.slots
	app.slot_menu.show_slots()
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await frame()
		check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(app.slot_menu.card.get_global_rect()), "Save picker fits " + str(viewport))
		await Harness.capture(app, "save-slots-" + str(viewport.x))
		app.slot_menu.show_creation(0)
		await frame()
		check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(app.slot_menu.card.get_global_rect()), "Creation fits " + str(viewport))
		var start: Button = app.slot_menu.find_child("CreateSave", true, false)
		check(app.slot_menu.card.get_global_rect().encloses(start.get_global_rect()), "Start game action stays visible at " + str(viewport))
		await Harness.capture(app, "save-creation-" + str(viewport.x))
		app.slot_menu.show_slots()
	app.slot_menu.show_creation(0)
	await frame()
	var starting_gold: SpinBox = app.slot_menu.find_child("StartingGold", true, false)
	starting_gold.get_line_edit().text = "4321"
	app.slot_menu.find_child("CreateSave", true, false).pressed.emit()
	await frame()
	check(app.game.data.balance == 4321.0 and app.game.tuning.session.start.starting_gold == 4321.0, "Typed starting gold is committed before creating the session")
	check(app.slot_active and app.game.is_creative() and not app.slot_menu.visible, "Create Creative activates slot")
	app.show_save_slots()
	await frame()
	check(not app.slot_menu.footer.visible and app.slot_menu.footer.get_child_count() == 0, "Saved games has no bottom return action with an active slot")
	app.slot_menu.find_child("BackButton", true, false).pressed.emit()
	await frame()
	check(app.slot_menu.visible and app.game.suspended, "Saved games back keeps the previous slot paused")
	check(app.slot_menu.find_child("OpenInfinite", true, false) != null and app.slot_menu.find_child("OpenCampaign", true, false) != null, "Saved games back opens main menu modes with an active slot")
	app.open_slot(0)
	app.panels.show_settings()
	check(app.panels.find_child("OpenDeveloperControls", true, false) != null, "Creative exposes editor")
	check(app.panels.find_child("OpenSoundSettings", true, false) != null, "Settings has sound submenu")
	app.panels.show_developer_controls()
	var controls = app.panels.find_child("DeveloperControls", true, false)
	controls.show_category("session")
	check(controls.inputs.starting_gold.value == 4321.0, "Existing customization editor shows saved starting gold")
	controls.inputs.starting_gold.value = 7654.0
	check(app.game.data.balance == 4321.0, "Changing future starting gold preserves current resources")
	app.panels.show_settings()
	app.panels.show_sound_settings()
	check(app.panels.mode == "sound", "Sound submenu opens")
	app.panels.show_settings()
	var upload: Button = app.panels.find_child("UploadBuild", true, false)
	check(upload != null and not upload.disabled, "Settings exposes Upload build")
	app.panels.content_scroll.ensure_control_visible(upload)
	await frame()
	check(app.panels.content_scroll.get_global_rect().grow(1).encloses(upload.get_global_rect()), "Upload build is reachable by scrolling Creative settings")
	upload.pressed.emit()
	await frame()
	check(app.slot_menu.find_child("SetupName", true, false) != null and app.slot_menu.find_child("SetupDescription", true, false) != null, "Export has name and description")
	await Harness.capture(app, "setup-export")
	app.slot_menu.find_child("SetupName", true, false).text = "Test setup"
	app.slot_menu.find_child("SetupDescription", true, false).text = "Reusable in either mode"
	var queued_before: int = app.public_builds.outbox.size()
	app.slot_menu.find_child("SaveLocalBuild", true, false).pressed.emit()
	check(app.public_builds.outbox.size() == queued_before, "Private build saving does not queue a public upload")
	check(slots.configurations().size() == 1, "Configuration saved to library")
	app.slot_menu.show_creation(1)
	app.slot_menu.find_child("ChooseConfiguration", true, false).pressed.emit()
	app.slot_menu.find_child("SelectConfiguration0", true, false).pressed.emit()
	app.slot_menu.find_child("ModeSurvival", true, false).pressed.emit()
	app.slot_menu.find_child("CreateSave", true, false).pressed.emit()
	await frame()
	check(not app.game.is_creative() and app.active_slot == 1, "UI imports as Survival")
	app.panels.show_settings()
	check(app.panels.find_child("OpenDeveloperControls", true, false) == null, "Survival hides editor")
	check(app.panels.find_child("UploadBuild", true, false).disabled, "Survival explains Creative-only public upload")
	app.panels.show_developer_controls()
	check(app.panels.mode == "settings", "Direct editor navigation blocked")
	app.field.set_unrestricted_camera(true)
	check(not app.field.unrestricted_camera, "Survival blocks free camera")
	app.show_save_slots()
	app.open_slot(0)
	check(app.game.is_creative() and app.active_slot == 0, "Switch back to Creative")
	app.show_save_slots()
	app.open_slot(1)
	check(not app.game.is_creative() and app.game.data.setup.name == "Test setup", "Return to saved Survival setup")
	app.show_save_slots()
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await frame()
		var revision: int = app.slot_menu.view_revision
		app.slot_menu.show_archive(1)
		await frame()
		var popup: PopupPanel = app.slot_menu.get_node("ArchiveConfirmation")
		check(popup.visible and popup.size.y < viewport.y * 0.75, "Archive is compact at " + str(viewport))
		check(app.slot_menu.view_revision == revision, "Archive preserves Saved games underneath")
		await Harness.capture(app, "archive-popup-" + str(viewport.x))
		popup.find_child("CancelConfirmation", true, false).pressed.emit()
		await frame()
		check(slots.occupied(1) and app.slot_menu.view_revision == revision, "Cancel preserves slot and saved games view")
	app.slot_menu.show_archive(1)
	await frame()
	app.slot_menu.get_node("ArchiveConfirmation").find_child("ConfirmAction", true, false).pressed.emit()
	await frame()
	check(not slots.occupied(1) and not app.slot_active, "Confirm frees the active slot")
	check(app.slot_menu.find_child("ScreenTitle", true, false).text == "Saved games", "Archive returns to refreshed Saved games")
	app.audio.set_suspended(true)
	app.audio.music.stop()
	app.audio.music.stream = null
	for pool in app.audio.voices.values():
		for voice in pool:
			voice.stop()
			voice.stream = null
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	for slot in range(3):
		for suffix in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(slots.path_for(slot) + suffix)
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute("user://slots-ui-placeholder.save" + suffix)
	print("Save UI: ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
