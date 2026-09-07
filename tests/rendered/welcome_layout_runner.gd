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
	for dimensions in [Vector2i(540,960), Vector2i(360,640), Vector2i(390,844), Vector2i(558,978), Vector2i(320,568), Vector2i(844,390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for i in 20: await process_frame
		var welcome: Control = app.slot_menu.find_child("WelcomeMenu", true, false)
		var bounds := Rect2(Vector2.ZERO, welcome.size)
		for element in [welcome.crest, welcome.title, welcome.subtitle, welcome.modes, welcome.battlefield, welcome.footer_rule, welcome.caption]:
			check(bounds.encloses(element.get_rect()), "Composition contains %s at %s" % [element.name, dimensions])
		check(welcome.battlefield.position.y >= welcome.subtitle.get_rect().end.y + 8, "Landscape clears the subtitle")
		check(not welcome.modes.get_rect().intersects(welcome.battlefield.get_rect()), "Landscape clears the actions")
		check(welcome.battlefield.size.y >= 100, "Landscape remains readable")
		for art in [welcome.crest, welcome.battlefield, welcome.footer_rule]:
			check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Decorative art never owns input")
		var buttons: Array[Node] = welcome.modes.get_children()
		check(buttons.size() == 3 and buttons[2].text == "Settings", "Settings is the third action")
		check(buttons[0].size.is_equal_approx(buttons[2].size), "All actions share dimensions")
		for button in buttons:
			check(button.size == Vector2(minf(320, welcome.size.x - 16), 56), "Original button dimensions remain exact")
		check(welcome.modes.get_theme_constant("separation") == 14, "Original button gaps remain exact")
		if dimensions.x >= 680:
			check(app.slot_menu.scroll.get_global_rect().encloses(welcome.modes.get_global_rect()), "Landscape exposes every action without scrolling")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/welcome-layout-%d.png" % dimensions.x)
		app.slot_menu.scroll.ensure_control_visible(buttons[-1])
		for i in 8: await process_frame
		check(app.slot_menu.scroll.get_global_rect().encloses(buttons[-1].get_global_rect()), "Settings stays reachable on short screens")
		app.slot_menu.scroll.scroll_vertical = 0
	var settings: Button = app.slot_menu.find_child("MainSettings", true, false)
	settings.pressed.emit()
	check(app.slot_menu.screen == "settings", "Settings opens")
	app.slot_menu.go_back()
	for i in 20: await process_frame
	check(app.slot_menu.screen == "main", "Settings returns to main")
	print("WELCOME LAYOUT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
