extends "res://tests/rendered/save_slots_runner.gd"

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://stats-ui-placeholder-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_save_slots()
	var menu: Control = app.slot_menu
	menu.slots.base_path = "user://stats-ui-" + str(Time.get_ticks_usec())
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	menu.show_creation(0)
	menu.find_child("ChooseStatConfiguration", true, false).pressed.emit()
	menu.find_child("CreateStatConfiguration", true, false).pressed.emit()
	await frame()
	menu.find_child("StatConfigurationName", true, false).text = "Survival test"
	var controls = menu.find_child("DeveloperControls", true, false)
	controls.show_category("enemies")
	controls.inputs.hp.get_line_edit().text = "444"
	menu.find_child("SaveStatConfiguration", true, false).pressed.emit()
	check(menu.slots.stat_configurations().size() == 1, "Save draft commits typed custom stats")
	var code: String = menu.slots.stat_configurations()[0].code
	check(VigilSaveSlots.Stats.decode(code).tuning.enemies.basic.hp == 444.0, "Saved code carries edited stat")
	menu.stat_browser.show_code(code)
	await frame()
	check(menu.find_child("CopyStatExport", true, false) != null, "Export code is available for transfer")
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = root.size
		menu.stat_browser.show_page(0)
		await frame()
		check(menu.find_child("BackButton", true, false).is_visible_in_tree() and menu.card.get_global_rect().encloses(menu.find_child("BackButton", true, false).get_global_rect()), "Configuration navigation remains visible")
		await Harness.capture(app, "stat-configurations-" + str(dimensions.x))
		var use: Button = menu.find_child("UseStatConfiguration", true, false)
		menu.scroll.ensure_control_visible(use)
		await frame()
		check(menu.card.get_global_rect().grow(1).encloses(use.get_global_rect()), "Saved stats are reachable at " + str(dimensions))
	menu.find_child("UseStatConfiguration", true, false).pressed.emit()
	menu.find_child("ModeSurvival", true, false).pressed.emit()
	menu.find_child("CreateSave", true, false).pressed.emit()
	await frame()
	check(app.game.tuning.enemies.basic.hp == 444.0 and not app.game.is_creative() and app.game.data.towers.is_empty(), "New Survival applies stats with an empty world")
	app.panels.show_settings()
	check(app.panels.find_child("OpenStatConfigurations", true, false) != null, "Survival exposes stat transfer from settings")
	app.panels.find_child("OpenStatConfigurations", true, false).pressed.emit()
	menu.find_child("CopyCurrentStats", true, false).pressed.emit()
	controls = menu.find_child("DeveloperControls", true, false)
	controls.show_category("enemies")
	controls.inputs.hp.value = 555.0
	check(app.game.tuning.enemies.basic.hp == 444.0, "Editing a copy leaves active Survival rules unchanged")
	menu.stat_browser.show_page()
	menu.find_child("ImportStatConfiguration", true, false).pressed.emit()
	menu.find_child("StatImportCode", true, false).text = "broken"
	menu.find_child("ConfirmStatImport", true, false).pressed.emit()
	check(menu.message.text.begins_with("Invalid") and menu.slots.stat_configurations().size() == 1, "Malformed import shows error and preserves library")
	menu.find_child("StatImportCode", true, false).text = code
	menu.find_child("ConfirmStatImport", true, false).pressed.emit()
	check(menu.slots.stat_configurations().size() == 2, "Import creates an independent configuration")
	for slot in range(3):
		for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(menu.slots.path_for(slot) + suffix)
	var directory := DirAccess.open(menu.slots.configurations_path())
	for file in directory.get_files(): DirAccess.remove_absolute(menu.slots.configurations_path().path_join(file))
	DirAccess.remove_absolute(menu.slots.configurations_path())
	app.queue_free()
	await process_frame
	print("STAT CONFIGURATION UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
