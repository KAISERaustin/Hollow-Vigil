extends "res://tests/rendered/unified_menu_runner.gd"
## Real camera/save boundary and failed-save exits through shared menu controls.

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://save-exit-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	await frames()
	await check_camera_saves()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames()
		await check_infinite_exit()
		await check_campaign_exit()
	print("SAVE_EXIT: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func check_camera_saves() -> void:
	app.field.set_unrestricted_camera(true)
	for zoom in [0.01, 0.22, 0.42, 1.65, 2.5, 100.0]:
		app.field.set_zoom(zoom, app.field.size * 0.5)
		app.persist()
		check(app.game.save_error.is_empty(), "Actual camera zoom saves: " + str(zoom))
		var saved := app.game.storage.read_candidate(app.game.save_path)
		check(not saved.is_empty() and is_equal_approx(saved.camera[2], zoom), "Stored zoom round trips: " + str(zoom))
	# A normal camera also raises the old 1.65 cap on larger viewports.
	app.field.set_unrestricted_camera(false)
	app.field.size = Vector2(1920, 1080)
	app.field.enforce_camera_limits()
	check(app.field.zoom > 1.65, "Viewport-dependent normal zoom exceeds former save cap")
	app.persist()
	check(app.game.save_error.is_empty(), "Normal viewport-dependent zoom saves")
	var before := FileAccess.get_file_as_string(app.game.save_path)
	for zoom in [0.0, -1.0, NAN, INF]:
		var invalid := app.game.snapshot()
		invalid.camera[2] = zoom
		check(not app.game.storage.write(app.game.save_path, invalid), "Invalid camera zoom still rejected: " + str(zoom))
		check(FileAccess.get_file_as_string(app.game.save_path) == before, "Invalid camera preserves last save")

func check_infinite_exit() -> void:
	app.slot_active = true
	app.game.suspended = false
	app.game.data.balance = 4000000.0
	app.persist()
	check(app.game.save_error.is_empty(), "Infinite exit starts from a valid save")
	var before := FileAccess.get_file_as_string(app.game.save_path)
	app.game.data.balance = -1.0
	app.show_game_menu()
	await press("ExitGame")
	check(menu.screen == "game_menu" and app.slot_active, "Failed save waits for exit decision")
	check(button("ConfirmAction") != null and button("ConfirmAction").text == "Exit anyway", "Failure offers Exit anyway")
	await press("CancelConfirmation")
	await press("ResumeGame")
	check(not menu.visible and not app.game.suspended and app.game.data.balance == -1.0, "Cancel can resume unchanged live progress")
	app.show_game_menu()
	await press("ExitGame")
	await press("ConfirmAction")
	check(menu.screen == "home" and not app.slot_active and app.game.suspended and not menu.held, "Confirmed failed-save exit releases Infinite session")
	check(FileAccess.get_file_as_string(app.game.save_path) == before, "Failed-save exit preserves earlier save bytes")
	# The same escape hatch must handle a filesystem error, not only validation.
	app.slot_active = true
	app.game.data.balance = 4000000.0
	var original_path: String = app.game.save_path
	app.game.save_path = "user://missing-save-directory-" + str(Time.get_ticks_usec()) + "/slot.save"
	app.show_game_menu()
	await press("ExitGame")
	await press("ConfirmAction")
	check(menu.screen == "home" and not app.slot_active, "Filesystem save failure still permits exit")
	app.game.save_path = original_path
	# A later successful save exits immediately without a warning.
	app.slot_active = true
	app.show_game_menu()
	await press("ExitGame")
	check(menu.screen == "home" and button("ConfirmAction") == null, "Successful save exits directly")

func check_campaign_exit() -> void:
	var value: Dictionary = menu.campaign_slots.summary(0)
	if value.is_empty(): value = menu.campaign_slots.create(0, "creative", "Exit test")
	check(not value.is_empty(), "Create valid Campaign slot")
	app.open_campaign_slot(0, value)
	app.campaign.set_process(false)
	var before := FileAccess.get_file_as_string(menu.campaign_slots.path_for(0))
	app.campaign.campaign_save.name = ""
	app.show_game_menu()
	await press("ExitGame")
	check(is_instance_valid(app.campaign) and app.campaign.paused, "Failed Campaign save retains live session for decision")
	await press("CancelConfirmation")
	await press("ResumeGame")
	check(is_instance_valid(app.campaign) and not menu.visible and not app.campaign.paused, "Cancel resumes Campaign")
	app.show_game_menu()
	await press("ExitGame")
	await press("ConfirmAction")
	check(menu.screen == "home" and not is_instance_valid(app.campaign) and not menu.held, "Confirmed failed-save exit closes Campaign")
	check(FileAccess.get_file_as_string(menu.campaign_slots.path_for(0)) == before, "Campaign failure preserves earlier save bytes")
