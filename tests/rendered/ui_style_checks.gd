extends SceneTree

const UI = preload("res://scripts/ui/interface.gd")
var app: VigilApp
var failures: Array[String] = []

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
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.balance = 1000000.0
	app.game.expand("-1,0")
	app.game.economy.build("rapid", "0,0", 0)
	app.game.economy.credit("1", 119.0)
	for viewport in [Vector2i(540, 960), Vector2i(360, 640), Vector2i(390, 844)]:
		root.size = viewport
		root.content_scale_size = viewport
		for factor in [1.0, 1.25, 1.5]:
			app.game.data.settings.text_scale = factor
			app.apply_ui_preferences()
			await settle()
			for screen in ["hud", "build", "expand", "rift", "core", "settings", "developer", "reset", "guide", "guide-enemies", "tower-info", "upgrade", "sell", "move", "target", "move-pick", "return"]:
				app.panels.close_sheet()
				app.close_return_popup()
				app.reset_scrim.hide()
				app.toast_label.modulate.a = 0
				app.field.camera = Vector2.ZERO
				match screen:
					"build": app.panels.select_pad("0,0", 1)
					"expand": app.panels.show_expansion("1,0")
					"rift": app.panels.show_entrance("-1,0")
					"core": app.panels.show_core()
					"settings": app.panels.show_settings()
					"developer": app.panels.show_developer_controls()
					"reset": app.panels.show_reset_confirmation()
					"guide": app.panels.show_info()
					"guide-enemies":
						app.panels.show_info()
						app.panels.guide.show_category("enemies")
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
				var bounds := Rect2(Vector2.ZERO, Vector2(viewport))
				if screen == "upgrade":
					var quote := app.tower_actions.upgrade_quote
					if not quote.is_visible_in_tree() or not app.field.get_global_rect().encloses(quote.get_global_rect()) or not quote.text.contains("gold"):
						failures.append(label + ": upgrade price is not visible inside the map")
				for panel in [app.hud, app.panels, app.tower_dialog.card, app.tower_move, app.return_card]:
					if panel.is_visible_in_tree() and not bounds.grow(1).encloses(panel.get_global_rect()):
						failures.append(label + ": panel outside viewport " + str(panel.get_global_rect()))
				if app.panels.visible and not screen.begins_with("guide"):
					var close := app.panels.find_child("CloseSheet", true, false) as Control
					if not bounds.encloses(close.get_global_rect()): failures.append(label + ": close inaccessible")
					for action in app.panels.action_footer.get_children():
						if action is Button and not bounds.encloses(action.get_global_rect()): failures.append(label + ": action inaccessible")
				if app.tower_dialog.visible and not bounds.encloses(app.tower_dialog.confirm.get_global_rect()): failures.append(label + ": confirm inaccessible")
				if screen == "tower-info" and app.tower_dialog.scroll.get_v_scroll_bar().visible:
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
				if screen.begins_with("guide"):
					var guide := app.panels.guide
					guide.scroll.grab_focus()
					var key := InputEventKey.new()
					key.keycode = KEY_END
					key.pressed = true
					Input.parse_input_event(key)
					await settle()
					key = key.duplicate()
					key.pressed = false
					Input.parse_input_event(key)
					if guide.scroll.scroll_vertical <= 0:
						failures.append(label + ": guide cannot scroll by keyboard")
					var last := guide.cards.get_child(-1) as Control
					if last.get_global_rect().end.y > guide.scroll.get_global_rect().end.y + 1:
						failures.append(label + ": last guide entry unreachable")
					guide.scroll.scroll_vertical = 0
					await settle()
				if app.tower_move.visible:
					if not app.field.get_global_rect().encloses(app.tower_move.get_global_rect()): failures.append(label + ": move prompt outside map")
					if not bounds.encloses(app.tower_move.cancel_button.get_global_rect()) or app.tower_move.cancel_button.size.x < 48: failures.append(label + ": move cancel inaccessible")
				if screen == "developer":
					var controls := app.panels.find_child("DeveloperControls", true, false)
					for section in ["enemies", "towers"]:
						controls.show_category(section)
						await settle()
						for slider in controls.sliders.values():
							app.panels.content_scroll.ensure_control_visible(slider)
							await settle()
							if not app.panels.content_scroll.get_global_rect().grow(1).encloses(slider.get_global_rect()):
								failures.append(label + ": slider cannot scroll fully into view")
							if slider.size.x < 100.0:
								failures.append(label + ": slider too narrow to drag")
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
	print("UI_STYLE: ", failures.size(), " failures; 17 screens, 3 viewports, 3 text scales")
	quit(0 if failures.is_empty() else 1)
