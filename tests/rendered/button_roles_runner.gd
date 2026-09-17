extends "res://tests/rendered/moonlit_theme_runner.gd"
## Fixed roles, legacy preference migration, thin rims and real menu interactions.

func fill_of(key: String) -> Color:
	return named(key).get_theme_stylebox("normal").bg_color

func run() -> void:
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app = VigilApp.new()
		app.load_saved_progress = false
		app.game.save_path = "user://button-roles-" + str(Time.get_ticks_usec())
		root.add_child(app)
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.set_process(false)
		app.private_backups.enabled = false
		app.audio.set_suspended(true)
		app.change_log.busy = true
		Engine.max_fps = 240
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var menu = app.slot_menu
		menu.show_settings(menu.show_main_menu)
		await inspect("fixed-settings")
		check(menu.find_child("SettingsButtonColors", true, false) == null, "Settings has no palette switch")
		check(fill_of("SettingsAccount") == UI.STEEL, "Account uses steel navigation")
		check(fill_of("SettingsSound") == UI.VIOLET, "Sound uses violet editing")
		check(fill_of("SettingsBugReport") == UI.BRONZE, "Reports use bronze management")
		check(fill_of("BackButton") == UI.SURFACE, "Back stays neutral iron")
		await press(named("SettingsSound"))
		check(menu.screen == "sound", "Sound action still opens its page")
		await back()
		check(menu.screen == "settings", "Back returns to Settings")
		var legacy := ConfigFile.new()
		legacy.set_value("preferences", "settings", {"button_palette": "dusk_violet", "audio": {"muted": true, "master": 0.37}})
		check(legacy.save(app.preferences_path()) == OK, "Legacy preference fixture saved")
		app.load_preferences()
		check(not app.game.data.settings.has("button_palette"), "Legacy palette preference is retired")
		check(app.game.data.settings.audio == {"muted": true, "master": 0.37}, "Sound preferences survive migration")
		app.persist()
		legacy.load(app.preferences_path())
		check(not legacy.get_value("preferences", "settings").has("button_palette"), "Next save removes retired preference from disk")
		check(fill_of("SettingsAccount") == UI.STEEL and fill_of("SettingsSound") == UI.VIOLET, "Old palette cannot recolor menus")
		var samples := VBoxContainer.new()
		samples.theme = app.theme
		app.add_child(samples)
		samples.hide()
		for fill in [UI.SURFACE, UI.GOLD, UI.STEEL, UI.SILVER, UI.VIOLET, UI.ROSE, UI.BRONZE, UI.COPPER, UI.DANGER]:
			var button := UI.accent_button("Role sample", func(): pass, fill)
			samples.add_child(button)
			for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var style: StyleBox = button.get_theme_stylebox(state)
				for side in ["left", "top", "right", "bottom"]:
					check(style.get("border_width_" + side) == 1, "Every button rim is one unit in " + state)
				check(style.border_color == Color.BLACK, "Button rim remains black")
				check(style.bg_color == (UI.DISABLED if state == "disabled" else fill), "Role stays fixed across interaction states")
				var role := "font_disabled_color" if state == "disabled" else ("font_pressed_color" if state in ["pressed", "hover_pressed"] else "font_color")
				check(contrast(button.get_theme_color(role), style.bg_color) >= 4.5, "Fixed role retains readable text")
		for fill in [UI.BG, UI.PANEL, UI.INSET]:
			var style := UI.surface(fill)
			for side in ["left", "top", "right", "bottom"]:
				check(style.get("border_width_" + side) == 1, "Panels and fields match the one-unit button rim")
		menu.show_home()
		await inspect("fixed-home")
		check(fill_of("Continue") == UI.GOLD and fill_of("Community") == UI.STEEL and fill_of("MyBuilds") == UI.BRONZE, "Progress, navigation and build roles coexist")
		menu.show_slots()
		menu.confirm_slot_deletion("campaign", 0)
		await inspect("fixed-confirmation")
		var popup := menu.get_child(menu.get_child_count() - 1) as PopupPanel
		await RenderingServer.frame_post_draw
		var pixel := root.get_texture().get_image().get_pixelv(popup.position + Vector2i(10, 10))
		check(absf(pixel.g - UI.PANEL.g) < 0.03, "Scrim stays behind the popup surface")
		await press(popup.find_child("CancelConfirmation", true, false))
		check(not is_instance_valid(popup) or not popup.visible, "Confirmation remains cancellable")
		app.queue_free()
		await process_frame
		await process_frame
	print("BUTTON ROLES: %d checks, %d failures; fixed roles, legacy preferences, touch navigation and thinner rims" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
