extends SceneTree

var app: VigilApp
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func settle() -> void:
	for frame in range(8):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://menu-layout.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.balance = 1000000.0
	app.game.expand("-1,0")
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await settle()
		# Empty-body expansion sheets must settle after cold opens and taller menus.
		for previous in ["closed", "settings", "build"]:
			if previous == "settings":
				app.panels.show_settings()
			elif previous == "build":
				app.panels.show_build()
			else:
				app.panels.close_sheet()
			await settle()
			app.panels.show_expansion("1,0")
			# Emulate the narrow provisional widths before the container's sort.
			app.panels.header_content.get_child(0).get_child(0).size.x = 1
			app.panels.action_button.size.x = 1
			app.panels.fit_sheet()
			await settle()
			check(app.panels.size.y < 170, "expansion too tall after " + previous + " at " + str(viewport) + ": " + str(app.panels.size.y))
			check(app.field.get_global_rect().encloses(app.panels.get_global_rect()), "expansion outside battlefield")
			var close := app.panels.find_child("CloseSheet", true, false) as Control
			check(app.panels.get_global_rect().encloses(close.get_global_rect()), "expansion close clipped")
			check(app.panels.get_global_rect().encloses(app.panels.action_button.get_global_rect()), "expansion claim clipped")
		app.panels.select_pad("0,0", 1)
		await settle()
		var choices := app.panels.sheet_content.get_child(0)
		check(choices.get_child_count() == Balance.TOWERS.size(), "missing build choices")
		for choice in choices.get_children():
			app.panels.content_scroll.ensure_control_visible(choice)
			await settle()
			check(app.panels.content_scroll.get_global_rect().grow(1).encloses(choice.get_global_rect()), "build choice unreachable at " + str(viewport))
		app.panels.show_expansion("1,0")
		await settle()
		check(app.panels.size.y < 170, "expansion contains unused space")
		app.panels.show_core()
		await settle()
		check(app.panels.sheet_content.get_child_count() > 0, "core opens an empty panel")
		app.panels.show_settings()
		await settle()
		var last_action := app.panels.sheet_content.get_child(-1)
		app.panels.content_scroll.ensure_control_visible(last_action)
		await settle()
		check(app.panels.content_scroll.get_global_rect().grow(1).encloses(last_action.get_global_rect()), "settings action unreachable at " + str(viewport))
		for game_mode in ["creative", "survival"]:
			app.game.data.mode = game_mode
			app.panels.show_settings()
			await settle()
			var settings_rect := app.panels.get_global_rect()
			app.panels.find_child("OpenSoundSettings", true, false).pressed.emit()
			await settle()
			check(app.panels.get_global_rect().is_equal_approx(settings_rect), game_mode + " sound moved from settings at " + str(viewport))
			app.panels.find_child("RestoreAudioDefaults", true, false).pressed.emit()
			await settle()
			check(app.panels.get_global_rect().is_equal_approx(settings_rect), "restoring sound defaults moved panel")
			var sound_back := app.panels.find_child("BackToSettings", true, false) as Button
			await settle()
			check(app.panels.header_content.get_global_rect().grow(1).encloses(sound_back.get_global_rect()), "sound back action unreachable at " + str(viewport))
			sound_back.pressed.emit()
			await settle()
			check(app.panels.mode == "settings" and app.panels.get_global_rect().is_equal_approx(settings_rect), "return from sound moved settings")
			app.panels.find_child("OpenCloudSaves", true, false).pressed.emit()
			await settle()
			check(app.panels.get_global_rect().is_equal_approx(app.get_global_rect()), game_mode + " account menu is not full screen at " + str(viewport))
			app.cloud.changed.emit()
			await settle()
			check(app.panels.get_global_rect().is_equal_approx(app.get_global_rect()), "rebuilding account menu lost full-screen layout")
			var cloud_back := app.panels.header_content.find_child("BackToSettings", true, false) as Button
			check(app.panels.get_global_rect().encloses(cloud_back.get_global_rect()), "account back action clipped at " + str(viewport))
			cloud_back.pressed.emit()
			await settle()
			check(not app.panels.visible, "account back action did not close backups")
		app.game.data.mode = "creative"
		app.panels.show_developer_controls()
		await settle()
		var controls := app.panels.find_child("DeveloperControls", true, false)
		for category in Balance.TUNING_FIELDS:
			controls.show_category(category)
			await settle()
			for index in range(controls.selector.item_count):
				controls.selector.select(index)
				controls.selector.item_selected.emit(index)
				await settle()
				for number in controls.inputs.values():
					app.panels.content_scroll.ensure_control_visible(number)
					await settle()
					check(app.panels.content_scroll.get_global_rect().grow(1).encloses(number.get_global_rect()), category + " number clipped at " + str(viewport))
					check(number.size.x >= 100, category + " number too narrow")
				check(not app.panels.content_scroll.get_v_scroll_bar().visible, category + " shows a scrollbar")
				var back := app.panels.find_child("BackToCategories", true, false) as Control
				check(app.field.get_global_rect().encloses(back.get_global_rect()), "developer back action clipped")
		app.panels.close_sheet()
	for failure in failures:
		push_error(failure)
	print("MENU_LAYOUT: ", failures.size(), " failures; compact menus and every developer type at three viewport sizes")
	quit(0 if failures.is_empty() else 1)
