extends "res://tests/rendered/unified_menu_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.show_home("campaign")
		await press("NewGame")
		await press("ChooseCreative")
		await press("NextPlayStyle")
		await press("ReviewNewGame")
		fill("GameName", "Level rules " + str(dimensions.x))
		await choose("SaveSlotChoice", [360, 390, 540].find(dimensions.x) + 1)
		await press("StartGame")
		app.campaign.set_process(false)
		await open_game_menu()
		await check_rules("campaign")
		await press("ExitGame")
	print("CAMPAIGN_LEVEL_RULES: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
