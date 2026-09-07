extends "res://tests/rendered/unified_menu_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://saved-slot-compatibility-" + str(Time.get_ticks_usec())
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	app.slot_active = false
	var game := VigilState.new(3815533380, "creative")
	game.add_developer_gold()
	check(game.expand("1,0"), "Create previously owned starter neighbor")
	game.data.regions["1,0"].boss = {"kind": "warden", "status": "defeated"}
	game.data.setup = {"name": "Existing game", "description": ""}
	var path: String = menu.slots.path_for(0)
	check(menu.slots.storage.write(path, game.data), "Earlier starter boss record remains saveable")
	var before := FileAccess.get_file_as_string(path)
	var invalid := game.data.duplicate(true)
	invalid.regions["1,0"].boss.kind = "unknown"
	check(not menu.slots.storage.valid_data(invalid), "Unknown boss identity remains invalid")
	invalid.regions["1,0"].boss = {"kind": "warden", "status": "active"}
	check(not menu.slots.storage.valid_data(invalid), "Malformed active encounter remains invalid")
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.show_home("infinite")
		await press("Continue")
		check(menu.find_child("ContinueGameSlot1", true, false) != null, "Existing slot offers Continue")
		check(menu.find_child("NewGameSlot1", true, false) == null, "Occupied slot never offers New game")
		check(FileAccess.get_file_as_string(path) == before, "Browsing preserves original save bytes")
	await press("ContinueGameSlot1")
	check(app.slot_active and app.active_slot == 0 and not menu.visible, "Continue enters gameplay in slot 1")
	check(app.game.data.setup.name == "Existing game" and app.game.data.regions.has("1,0"), "Continue preserves named world and owned territory")
	var broken_path: String = menu.slots.path_for(1)
	var file := FileAccess.open(broken_path, FileAccess.WRITE)
	file.store_string("unreadable save")
	file.close()
	menu.show_slots()
	check(menu.find_child("NewGameSlot2", true, false) == null, "Unreadable slot cannot start a replacement")
	await press("RecoverGameSlot2")
	check(menu.screen == "backups", "Recovery action opens Backups")
	check(FileAccess.get_file_as_string(broken_path) == "unreadable save", "Recovery navigation preserves unreadable bytes")
	print("SAVED_SLOT_CONTINUE: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
