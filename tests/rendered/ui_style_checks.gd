extends SceneTree

const UI = preload("res://scripts/ui/interface.gd")
var app: VigilApp
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 90)
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
			for screen in ["hud", "build", "expand", "rift", "core", "settings", "reset", "guide", "upgrade", "sell", "return"]:
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
					"reset": app.panels.show_reset_confirmation()
					"guide": app.panels.show_info()
					"upgrade", "sell":
						app.panels.select_pad("0,0", 0)
						app.tower_dialog.open_action(screen)
					"return": app.show_return_earnings(376)
				app.update_hud()
				await settle()
				var label := "%s-%d-%d" % [screen, viewport.x, roundi(factor * 100)]
				var bounds := Rect2(Vector2.ZERO, Vector2(viewport))
				for panel in [app.hud, app.panels, app.tower_dialog.card, app.return_card]:
					if panel.is_visible_in_tree() and not bounds.grow(1).encloses(panel.get_global_rect()):
						failures.append(label + ": panel outside viewport " + str(panel.get_global_rect()))
				if app.panels.visible and screen != "guide":
					var close := app.panels.find_child("CloseSheet", true, false) as Control
					if not bounds.encloses(close.get_global_rect()): failures.append(label + ": close inaccessible")
					for action in app.panels.action_footer.get_children():
						if action is Button and not bounds.encloses(action.get_global_rect()): failures.append(label + ": action inaccessible")
				if app.tower_dialog.visible and not bounds.encloses(app.tower_dialog.confirm.get_global_rect()): failures.append(label + ": confirm inaccessible")
				if factor == 1.0 or viewport.x == 390:
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
	print("UI_STYLE: ", failures.size(), " failures; 11 screens, 3 viewports, 3 text scales")
	quit(0 if failures.is_empty() else 1)
