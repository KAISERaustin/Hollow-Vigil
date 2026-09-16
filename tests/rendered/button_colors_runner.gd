extends "res://tests/rendered/moonlit_theme_runner.gd"
## Exercise real palette selections, live existing styles and disk preferences.

func run() -> void:
	var save_path := "user://button-colors-" + str(Time.get_ticks_usec())
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app = VigilApp.new()
		app.load_saved_progress = false
		app.game.save_path = save_path
		root.add_child(app)
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.set_process(false)
		app.private_backups.enabled = false
		app.audio.set_suspended(true)
		Engine.max_fps = 240
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var secondary := UI.button("Existing secondary", func(): pass)
		var primary := UI.gold_button("Existing primary", func(): pass)
		var danger := UI.accent_button("Delete", func(): pass, UI.DANGER)
		var samples := VBoxContainer.new()
		samples.theme = app.theme
		samples.add_child(secondary)
		samples.add_child(primary)
		samples.add_child(danger)
		app.add_child(samples)
		samples.hide()
		app.slot_menu.show_settings(app.slot_menu.show_main_menu)
		await press(named("SettingsButtonColors"))
		check(app.slot_menu.screen == "button_colors", "Settings opens Button colors")
		for key in UI.BUTTON_PALETTES:
			await press(named("Palette_" + key))
			check(UI.button_palette == key, "Tap applies " + key)
			check(secondary.get_theme_stylebox("normal").bg_color == UI.BUTTON_PALETTES[key].secondary, "Existing secondary updates immediately")
			check(primary.get_theme_stylebox("normal").bg_color == UI.BUTTON_PALETTES[key].primary, "Existing primary updates immediately")
			check(danger.get_theme_stylebox("normal").bg_color == UI.DANGER, "Destructive meaning stays cloak red")
			for button in [secondary, primary, danger]:
				for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
					var style: StyleBox = button.get_theme_stylebox(state)
					check(style.border_width_left == 2 and style.border_width_top == 2, "All button states retain the thinner rim")
					var role := "font_disabled_color" if state == "disabled" else ("font_pressed_color" if state in ["pressed", "hover_pressed"] else "font_color")
					check(contrast(button.get_theme_color(role), style.bg_color) >= 4.5, "Palette preserves text contrast")
			var selected: Button = named("Palette_" + key)
			check(selected.text == "Selected" and selected.button_pressed, "Selection is explicitly labeled")
			var scroll: ScrollContainer = app.slot_menu.scroll
			var overflow := scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page
			if overflow > 1:
				await swipe(scroll.global_position + Vector2(2, scroll.size.y * 0.8), Vector2(0, -100))
				check(UI.button_palette == key, "Swiping retains the selected colors")
			await inspect("palette-" + key)
			UI.set_button_palette("invalid")
			app.load_preferences()
			check(UI.button_palette == key, "Reloaded disk preferences restore " + key)
		await back()
		check(app.slot_menu.screen == "settings", "Back returns to Settings")
		app.slot_menu.show_slots()
		app.slot_menu.confirm_slot_deletion("campaign", 0)
		await inspect("palette-confirmation")
		var popup := app.slot_menu.get_child(app.slot_menu.get_child_count() - 1) as PopupPanel
		await RenderingServer.frame_post_draw
		var pixel := root.get_texture().get_image().get_pixelv(popup.position + Vector2i(10, 10))
		check(absf(pixel.g - UI.PANEL.g) < 0.03, "Scrim stays behind the popup's opaque surface")
		await press(popup.find_child("CancelConfirmation", true, false))
		check(not is_instance_valid(popup) or not popup.visible, "Confirmation remains cancellable")
		app.queue_free()
		await process_frame
		await process_frame
	UI.set_button_palette("moonlit_iron")
	print("BUTTON COLORS: %d checks, %d failures; live updates, four palettes, disk persistence, touch selection, thinner borders" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
