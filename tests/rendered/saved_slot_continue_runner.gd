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
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames()
		var back := button("GameMenuButton") as Button
		check(back != null and back.text == "←" and back.accessibility_name == "Back to saved games", "Infinite toolbar uses an accessible back arrow")
		app.game.data.balance += 123.0
		var balance: float = app.game.data.balance
		await press("GameMenuButton")
		check(menu.screen == "slots" and menu.game_type == "infinite" and not app.slot_active and app.game.suspended, "Infinite Back saves and returns directly to saved games")
		await press("ContinueGameSlot1")
		check(is_equal_approx(app.game.data.balance, balance), "Continue restores progress saved by Infinite Back")
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
	menu.show_main_menu()
	await press("OpenCampaign")
	check(menu.screen == "home" and menu.game_type == "campaign", "Infinite saves do not change empty Campaign destination")
	for mode in ["survival", "creative"]:
		var slot: int = 0 if mode == "survival" else 1
		var value: Dictionary = menu.campaign_slots.create(slot, mode, "Saved " + mode)
		var saved_run := preload("res://scripts/campaign/run.gd").new(2, {}, mode)
		check(saved_run.build(6, "rapid"), "Prepare saved Campaign tower")
		saved_run.wave = slot
		check(saved_run.start_wave(), "Prepare saved Campaign wave")
		value.completed = 2
		value.checkpoint = saved_run.checkpoint()
		check(menu.campaign_slots.save_slot(slot, value), "Save Campaign with level checkpoint")
		var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(value.checkpoint))
		for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			var stored_checkpoint: Dictionary = menu.campaign_slots.summary(slot).checkpoint
			root.size = dimensions
			root.content_scale_size = dimensions
			menu.show_main_menu()
			await press("OpenCampaign")
			check(menu.screen == "slots" and menu.game_type == "campaign", "Campaign opens saved games directly")
			await press("ContinueGameSlot" + str(slot + 1))
			app.campaign.set_process(false)
			check(app.campaign.page == "map" and app.campaign.run == null and not menu.visible, "Campaign Continue opens map without running saved level")
			check(app.campaign.active_campaign_slot == slot and app.campaign.campaign_save.name == value.name, "Continue opens selected Campaign slot")
			check(app.campaign.progress.data.completed_levels == 2, "Continue preserves unlocked level progress")
			check(menu.campaign_slots.summary(slot).checkpoint == stored_checkpoint, "Opening map preserves stored level checkpoint")
			var saved_games := button("CampaignSavedGames")
			check(saved_games != null and saved_games.text == "←", "Campaign map uses a back arrow")
			await press("CampaignSavedGames")
			check(menu.screen == "slots" and menu.game_type == "campaign" and not is_instance_valid(app.campaign), "Map returns directly to Campaign saved games")
			await press("BackButton")
			check(menu.screen == "main", "Campaign saved games Back returns directly to main")
			await press("OpenCampaign")
			check(menu.campaign_slots.summary(slot).checkpoint == stored_checkpoint, "Returning to saved games preserves checkpoint")
			await press("ContinueGameSlot" + str(slot + 1))
			app.campaign.set_process(false)
			await press("CampaignLevel1")
			check(app.campaign.page == "briefing", "Another unlocked level opens its briefing")
			await press("CampaignBack")
			check(menu.campaign_slots.summary(slot).checkpoint == stored_checkpoint, "Previewing another level preserves saved checkpoint")
			await press("CampaignLevel3")
			check(app.campaign.page == "battle" and app.campaign.run.mission.index == 2, "Selecting saved level resumes its battle")
			check(JSON.parse_string(JSON.stringify(app.campaign.run.checkpoint())) == checkpoint, "Resumed level preserves saved wave and build")
			check(app.campaign.paused, "Loaded Campaign wave waits for player to start")
			check(not app.campaign.wave_button.disabled and app.campaign.wave_button.text == "Start wave %d" % (saved_run.wave + 1), "Loaded wave offers Start for its saved wave number")
			for step in 20: app.campaign._process(0.1)
			check(app.campaign.run.wave_time == 0.0 and app.campaign.run.game.combat.enemies.is_empty(), "Waiting after Continue never advances or spawns the wave")
			await press("CampaignWaves")
			app.campaign.dialog.hide()
			await press("GameMenuButton")
			check(app.campaign.page == "map" and not menu.visible, "Level back arrow returns directly to the map")
			check(menu.campaign_slots.summary(slot).checkpoint == checkpoint, "Returning to map preserves the saved wave and build")
			await press("CampaignLevel3")
			app.campaign._process(0.1)
			check(app.campaign.paused and app.campaign.run.wave_time == 0.0, "Returning from map keeps loaded wave stopped")
			var toolbar: Control = app.campaign.game_toolbar
			check(toolbar.menu_button.text == "←" and is_equal_approx(toolbar.menu_button.global_position.x, toolbar.global_position.x), "Back arrow sits at the far left")
			check(toolbar.pause_button.global_position.x > toolbar.menu_button.get_global_rect().end.x, "Playback sits to the right of Back")
			check(is_equal_approx(toolbar.speed_button.get_global_rect().end.x, toolbar.get_global_rect().end.x), "Speed sits at the far right")
			await press("StartCampaignWave")
			check(not app.campaign.paused, "Start explicitly releases loaded wave")
			app.campaign._process(0.1)
			check(app.campaign.run.wave_time > 0.0 and app.campaign.run.next_spawn > 0, "Wave advances and spawns only after Start")
			check(JSON.parse_string(JSON.stringify(app.campaign.run.checkpoint())) == checkpoint, "Starting loaded wave preserves the original checkpoint")
			var wave_time: float = app.campaign.run.wave_time
			await press("PauseButton")
			app.campaign._process(0.1)
			check(app.campaign.run.wave_time == wave_time, "Playback pause still freezes a running wave")
			await press("StartCampaignWave")
			check(not app.campaign.paused and app.campaign.run.wave_time == wave_time, "Start resumes a paused wave without restarting it")
			await press("GameMenuButton")
			check(app.campaign.page == "map" and not menu.visible, "Running level Back also returns directly to map")
			await press("CampaignSavedGames")
			check(menu.screen == "slots" and not is_instance_valid(app.campaign), "Map exits back to saved games")
