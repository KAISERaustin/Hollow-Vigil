extends SceneTree

const UI = preload("res://scripts/ui/shared/interface.gd")
const ParchmentStyle = preload("res://scripts/ui/shared/parchment_style.gd")
var app: VigilApp
var failures: Array[String] = []

func check_borders(screen: String) -> void:
	# Inspect instantiated controls, including local overrides that can bypass
	# the shared token and silently restore mixed border weights on one screen.
	for control: Control in app.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree(): continue
		var roles: Array[String] = []
		if control is PanelContainer: roles = ["panel"]
		elif control is Button: roles = ["normal", "hover", "pressed", "disabled"]
		elif control is Separator: roles = ["separator"]
		elif control is Label and control.has_theme_stylebox_override("normal"): roles = ["normal"]
		for role in roles:
			var style := control.get_theme_stylebox(role)
			var context := "%s: %s/%s" % [screen, control.name, role]
			if style is StyleBoxLine:
				if style.thickness != 3 or style.color != Color.BLACK:
					failures.append(context + ": divider must be three units of black ink")
			elif style is StyleBoxFlat or style is ParchmentStyle:
				for side in ["left", "top", "right", "bottom"]:
					var width: int = style.get("border_width_" + side)
					if width != 0 and (width != 3 or style.border_color != Color.BLACK):
						failures.append(context + ": " + side + " border must be three units of black ink")

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func settle() -> void:
	for i in range(6):
		await process_frame

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://ui-style.save"
	# Retired preferences must not affect runtime behavior.
	app.game.data.settings.low_power = true
	app.game.data.settings.text_scale = 1.5
	app.game.data.settings.reduced_motion = true
	root.add_child(app)
	if Engine.max_fps != 60 or UI.text_scale != 1.0:
		failures.append("legacy settings changed FPS or text size")
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.balance = 1000000.0
	app.game.expand("-1,0")
	app.game.economy.build("rapid", "0,0", 0)
	app.game.economy.credit("1", 119.0)
	for viewport in [Vector2i(540, 960), Vector2i(360, 640), Vector2i(390, 844)]:
		root.size = viewport
		root.content_scale_size = viewport
		for factor in [1.0]:
			app.game.data.settings.text_scale = factor
			app.apply_ui_preferences()
			await settle()
			for screen in ["hud", "build", "expand", "rift", "castle-rift", "core", "settings", "developer", "reset", "tower-info", "upgrade", "sell", "move", "target", "move-pick", "return"]:
				app.panels.close_sheet()
				app.close_return_popup()
				app.reset_scrim.hide()
				app.toast_label.modulate.a = 0
				app.field.camera = Vector2.ZERO
				match screen:
					"build": app.panels.select_pad("0,0", 1)
					"expand": app.panels.show_expansion("1,0")
					"rift": app.panels.show_entrance("-1,0")
					"castle-rift":
						var original_style: String = app.game.data.regions["-1,0"].style
						app.game.data.regions["-1,0"].style = "castle_ruin"
						app.panels.show_entrance("-1,0")
						app.game.data.regions["-1,0"].style = original_style
					"core": app.panels.show_core()
					"settings":
						app.panels.show_settings()
						for button in app.panels.find_children("*", "Button", true, false):
							if button.text.begins_with("Power saving:") or button.text.begins_with("Text size:") or button.text.begins_with("Reduced motion:"):
								failures.append("retired setting visible: " + button.text)
					"developer": app.panels.show_developer_controls()
					"reset": app.panels.show_reset_confirmation()
					"tower-info":
						app.panels.select_pad("0,0", 0)
						app.tower_dialog.open_action("info")
					"upgrade", "sell", "move", "target":
						app.panels.select_pad("0,0", 0)
						app.tower_dialog.open_action(screen)
					"move-pick":
						app.panels.select_pad("0,0", 0)
						app.tower_dialog.open_action("move")
						app.tower_dialog.commit(app.tower_dialog.revision)
					"return": app.show_return_earnings(376)
				app.update_hud()
				await settle()
				var label := "%s-%d-%d" % [screen, viewport.x, roundi(factor * 100)]
				check_borders(label)
				var bounds := Rect2(Vector2.ZERO, Vector2(viewport))
				if screen == "upgrade":
					var quote := app.tower_actions.upgrade_quote
					if not quote.is_visible_in_tree() or not app.field.get_global_rect().encloses(quote.get_global_rect()) or not quote.text.contains("gold"):
						failures.append(label + ": upgrade price is not visible inside the map")
				for panel in [app.hud, app.panels, app.tower_dialog.card, app.tower_move, app.return_card]:
					if panel.is_visible_in_tree() and not bounds.grow(1).encloses(panel.get_global_rect()):
						failures.append(label + ": panel outside viewport " + str(panel.get_global_rect()))
				if app.panels.visible:
					var close := app.panels.find_child("CloseSheet", true, false) as Control
					if not bounds.encloses(close.get_global_rect()): failures.append(label + ": close inaccessible")
					for action in app.panels.action_footer.get_children():
						if action is Button and not bounds.encloses(action.get_global_rect()): failures.append(label + ": action inaccessible")
				if app.tower_dialog.visible and not bounds.encloses(app.tower_dialog.confirm.get_global_rect()): failures.append(label + ": confirm inaccessible")
				if screen == "tower-info" and app.tower_dialog.body.size.y > app.tower_dialog.scroll.size.y:
					var scroll := app.tower_dialog.scroll
					scroll.grab_focus()
					var key := InputEventKey.new()
					key.keycode = KEY_END
					key.pressed = true
					Input.parse_input_event(key)
					await settle()
					key = key.duplicate()
					key.pressed = false
					Input.parse_input_event(key)
					if scroll.scroll_vertical <= 0:
						failures.append(label + ": tower details cannot scroll by keyboard")
					scroll.scroll_vertical = 0
					await settle()
				if screen == "reset" and viewport.x == 540 and factor == 1.0 and app.panels.content_scroll.get_v_scroll_bar().visible:
					failures.append(label + ": needless reset scrollbar")
				if app.tower_move.visible:
					if not app.field.get_global_rect().encloses(app.tower_move.get_global_rect()): failures.append(label + ": move prompt outside map")
					if not bounds.encloses(app.tower_move.cancel_button.get_global_rect()) or app.tower_move.cancel_button.size.x < 48: failures.append(label + ": move cancel inaccessible")
				if screen == "developer":
					var controls := app.panels.find_child("DeveloperControls", true, false)
					for section in ["enemies", "towers"]:
						controls.show_category(section)
						await settle()
						for number in controls.inputs.values():
							app.panels.content_scroll.ensure_control_visible(number)
							await settle()
							if not app.panels.content_scroll.get_global_rect().grow(1).encloses(number.get_global_rect()):
								failures.append(label + ": number cannot scroll fully into view")
							if number.size.x < 100.0:
								failures.append(label + ": number too narrow to edit")
					controls.show_category("enemies")
					app.panels.content_scroll.scroll_vertical = 0
					await settle()
				if factor == 1.0 or viewport.x == 390 or screen == "tower-info":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/style-" + label + ".png")
	app.panels.close_sheet()
	app.close_return_popup()
	app.game.data.settings.text_scale = 1.0
	app.apply_ui_preferences()
	# Theme fonts must actually expose different metrics for regular and bold.
	print("FONT_METRICS: ", UI.font(400).get_string_size("Hollow Vigil", 0, -1, 24), " / ", UI.font(700).get_string_size("Hollow Vigil", 0, -1, 24))
	for failure in failures:
		push_error(failure)
	print("UI_STYLE: ", failures.size(), " failures; 16 screens, 3 viewports, standard text size")
	quit(0 if failures.is_empty() else 1)
