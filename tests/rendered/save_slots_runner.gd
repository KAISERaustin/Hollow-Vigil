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
	app.slot_menu.find_child("CreateCreative", true, false).pressed.emit()
	await frame()
	check(app.slot_active and app.game.is_creative() and not app.slot_menu.visible, "Create Creative activates slot")
	app.panels.show_settings()
	check(app.panels.find_child("OpenDeveloperControls", true, false) != null, "Creative exposes editor")
	app.show_save_slots(true)
	await frame()
	check(app.slot_menu.find_child("SetupName", true, false) != null and app.slot_menu.find_child("SetupDescription", true, false) != null, "Export has name and description")
	await Harness.capture(app, "setup-export")
	var code := slots.export_build(app.game, "Test setup", "Reusable in either mode")
	app.slot_menu.show_creation(1)
	app.slot_menu.find_child("SetupImportCode", true, false).text = code
	app.slot_menu.find_child("CreateSurvival", true, false).pressed.emit()
	await frame()
	check(not app.game.is_creative() and app.active_slot == 1, "UI imports as Survival")
	app.panels.show_settings()
	check(app.panels.find_child("OpenDeveloperControls", true, false) == null, "Survival hides editor")
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
	app.slot_menu.show_archive(1)
	await frame()
	check(app.slot_menu.visible, "Archive confirmation opens")
	app.queue_free()
	await process_frame
	for slot in range(3):
		for suffix in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(slots.path_for(slot) + suffix)
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute("user://slots-ui-placeholder.save" + suffix)
	print("Save UI: ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
