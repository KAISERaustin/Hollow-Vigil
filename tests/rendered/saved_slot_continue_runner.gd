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
	root.size = Vector2i(540, 960)
	root.content_scale_size = root.size
	for type in ["campaign", "infinite"]:
		menu.show_main_menu()
		await press("Open" + type.capitalize())
		check(menu.screen == "home" and menu.game_type == type, "Empty mode opens its options: " + type)
		for key in ["Continue", "NewGame", "MyBuilds", "Community"]:
			check(button(key) != null, "Empty mode offers " + key)
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
		menu.show_main_menu()
		await press("OpenInfinite")
		check(menu.screen == "slots" and menu.game_type == "infinite", "Infinite opens saved games directly")
		check(menu.find_child("ContinueGameSlot1", true, false) != null, "Existing slot offers Continue")
		check(menu.find_child("NewGameSlot1", true, false) == null, "Occupied slot never offers New game")
		check(FileAccess.get_file_as_string(path) == before, "Browsing preserves original save bytes")
		await press("BackButton")
		check(menu.screen == "main", "Saved games Back returns directly to main")
		await press("OpenInfinite")
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
	await check_campaign_continue()
	print("SAVED_SLOT_CONTINUE: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func check_campaign_continue() -> void:
	for mode in ["survival", "creative"]:
		for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			menu.campaign_slots.base_path = "user://fresh-level-" + str(Time.get_ticks_usec())
			var value: Dictionary = menu.campaign_slots.create(0, mode, "Fresh entry")
			var old_run := preload("res://scripts/campaign/run.gd").new(2, {}, mode)
			check(old_run.build(6, "rapid"), "Prepare old tower layout")
			old_run.wave = 1
			check(old_run.start_wave(), "Prepare old wave")
			value.completed = 2
			value.checkpoint = old_run.checkpoint()
			check(menu.campaign_slots.save_slot(0, value), "Legacy checkpoint remains readable")
			app.open_campaign_slot(0, value)
			app.campaign.set_process(false)
			await press("CampaignLevel3")
			check(button("BeginCampaignMission").text == "Begin level", "Entry never offers resume")
			await press("BeginCampaignMission")
			var campaign = app.campaign
			check(campaign.run.wave == 0 and campaign.run.phase == "planning" and campaign.run.game.data.towers.is_empty(), "Legacy attempt starts fresh")
			check(campaign.run.health == campaign.run.mission.flame and campaign.run.game.data.balance == campaign.run.mission.gold, "Starting resources restored")
			check(menu.campaign_slots.summary(0).checkpoint.is_empty(), "Legacy checkpoint cleared on entry")
			check(campaign.run.build(6, "rapid"), "Build in new attempt")
			check(menu.campaign_slots.summary(0).checkpoint.is_empty(), "Placed towers are not saved")
			await press("GameMenuButton")
			check(campaign.exit_confirmation and campaign.page == "battle", "Back requires exit confirmation")
			await press("CancelCampaignExit")
			check(not campaign.run.game.data.towers.is_empty(), "Cancel retains current attempt")
			check(campaign.run.start_wave(), "Start wave before exit")
			await press("GameMenuButton")
			await press("ConfirmCampaignExit")
			check(campaign.page == "briefing", "Exit returns to level information")
			await press("BeginCampaignMission")
			check(campaign.run.wave == 0 and campaign.run.game.data.towers.is_empty(), "Reentry clears towers and waves")
			check(campaign.progress.data.completed_levels == 2, "Completed levels remain saved")
			await press("GameMenuButton")
			await press("ConfirmCampaignExit")
			await press("CampaignBack")
			await press("CampaignSavedGames")