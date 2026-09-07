extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 60)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.slot_menu = preload("res://scripts/ui/unified_menu.gd").new()
	app.slot_menu.app = app
	app.add_child(app.slot_menu)
	for dimensions in [Vector2i(540,960), Vector2i(360,640), Vector2i(390,844), Vector2i(558,978)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for i in 20: await process_frame
		var welcome: Control = app.slot_menu.find_child("WelcomeMenu", true, false)
		var bounds := Rect2(Vector2.ZERO, welcome.size)
		for element in [welcome.crest, welcome.title, welcome.subtitle, welcome.modes, welcome.battlefield, welcome.caption]:
			check(bounds.encloses(element.get_rect()), "Composition contains %s at %s" % [element.name, dimensions])
		check(welcome.battlefield.position.y - welcome.modes.get_rect().end.y <= 24, "Art stays below buttons without a large gap")
		check(welcome.battlefield.size.y >= 90, "Battlefield remains readable")
		var buttons: Array[Node] = welcome.modes.get_children()
		check(buttons.size() == 3 and buttons[2].text == "Settings", "Settings is the third action")
		check(buttons[0].size.is_equal_approx(buttons[2].size), "All actions share dimensions")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/welcome-layout-%d.png" % dimensions.x)
	var settings: Button = app.slot_menu.find_child("MainSettings", true, false)
	settings.pressed.emit()
	check(app.slot_menu.screen == "settings", "Settings opens")
	app.slot_menu.go_back()
	for i in 20: await process_frame
	check(app.slot_menu.screen == "main", "Settings returns to main")
	print("WELCOME LAYOUT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
