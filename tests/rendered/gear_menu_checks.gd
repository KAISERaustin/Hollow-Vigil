extends SceneTree

const Harness = preload("res://tests/rendered/visual_smoke.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Art = preload("res://scripts/rendering/actors/relic_art.gd")
var app: VigilApp
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in range(8):
		await process_frame

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://gear-menu.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app.panels.show_developer_controls()
		await settle()
		var controls = app.panels.find_child("DeveloperControls", true, false)
		app.panels.content_scroll.ensure_control_visible(controls.tabs.gear)
		await settle()
		await Harness.tap(app, controls.tabs.gear.get_global_rect().get_center(), dimensions.x == 360)
		await settle()
		check(controls.category == "gear" and controls.selector.item_count == 18, "Gear category opens all eighteen types at " + str(dimensions))
		check(controls.hint.text.contains("18 gear types"), "Gear total appears in the menu")
		for index in range(18):
			controls.selector.select(index)
			controls.selector.item_selected.emit(index)
			await settle()
			var kind: String = controls.selected_kind
			check(controls.inputs.size() == Balance.editable_fields_for("gear", kind).size(), "Every active numeric field is present: " + kind)
			check(controls.description.text.contains(Balance.BOSSES[Relics.DEFINITIONS[kind].boss].name), "Editor identifies source boss")
			for stat in controls.inputs:
				var input: SpinBox = controls.inputs[stat]
				check(is_equal_approx(input.value, Balance.tuned_value("gear", kind, stat, app.game.tuning)), "Editor displays exact current/default value without rounding: " + kind + "/" + stat)
				app.panels.content_scroll.ensure_control_visible(input.get_parent())
				await settle()
				check(app.panels.content_scroll.get_global_rect().grow(2).encloses(input.get_parent().get_global_rect()), "Field row reachable at " + str(dimensions) + ": " + kind + "/" + stat)
				check(input.get_global_rect().end.x <= app.size.x, "Input stays within phone width")
				var before := input.value
				input.get_line_edit().text = str(minf(input.max_value, before + input.step))
				input.apply()
				check(is_equal_approx(Balance.tuned_value("gear", kind, stat, app.game.tuning), input.value), "Typing changes only selected gear field")
				# Live description wrapping can resize the sheet after an edit.
				# Resolve that layout before scrolling to the next field's bounds.
				await settle()
			app.panels.content_scroll.scroll_vertical = 0
			await settle()
			check(app.get_global_rect().encloses(app.panels.get_global_rect()), "Gear editor fits viewport")
			if kind in ["warden", "prior_mirror", "mourning_matriarch"]:
				await Harness.capture(app, "gear-" + kind + "-" + str(dimensions.x))
		# The final entry is reachable in the bounded selection menu, including touch.
		app.panels.content_scroll.ensure_control_visible(controls.selector)
		await settle()
		await Harness.tap(app, controls.selector.get_global_rect().get_center())
		await settle()
		var popup: PopupPanel = controls.selector.get_popup()
		check(popup.visible and popup.size.y <= mini(560, dimensions.y - 24), "Eighteen-item selection menu remains bounded")
		popup.hide()
		var reset: Button = controls.find_child("ResetSelectedBalance", true, false)
		app.panels.content_scroll.ensure_control_visible(reset)
		await settle()
		await Harness.tap(app, reset.get_global_rect().get_center(), dimensions.x == 360)
		check(Balance.definition("gear", controls.selected_kind, app.game.tuning) == Balance.GEAR[controls.selected_kind], "Reset selected restores the current piece")
		app.panels.close_sheet()
		var saved: Dictionary = app.game.storage.read_candidate(app.game.save_path)
		check(not saved.is_empty() and preload("res://tests/unit/developer_tier_checks.gd").same_values(saved.settings.developer_balance, app.game.tuning), "Editor persists all gear changes when closed")
		app.game.reset_developer_balance()
	await lineup()
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(app.game.save_path + suffix):
			DirAccess.remove_absolute(app.game.save_path + suffix)
	app.queue_free()
	await process_frame
	print("GEAR MENU: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func lineup() -> void:
	root.size = Vector2i(1080, 960)
	root.content_scale_size = root.size
	var board := Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(board)
	board.draw.connect(func():
		board.draw_rect(Rect2(Vector2.ZERO, board.size), Color("171e24"))
		var font := ThemeDB.fallback_font
		var row := 0
		for boss in Relics.BOSS_DROPS:
			var y := 22 + row * 155
			board.draw_string(font, Vector2(30, y), Balance.BOSSES[boss].name, HORIZONTAL_ALIGNMENT_LEFT, 1000, 18, Color("d4c18f"))
			for column in range(3):
				var kind: String = Relics.BOSS_DROPS[boss][column]
				var x := 180 + column * 350
				Art.draw(board, kind, Vector2(x, y + 60), 2.8)
				board.draw_string(font, Vector2(x - 160, y + 120), Relics.DEFINITIONS[kind].name, HORIZONTAL_ALIGNMENT_CENTER, 320, 20, Color("eee4ca"))
			row += 1
	)
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/gear-lineup.png")
	board.queue_free()
