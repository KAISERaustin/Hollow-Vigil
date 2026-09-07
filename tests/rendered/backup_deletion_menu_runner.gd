extends "res://tests/rendered/unified_menu_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://deletion-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var recovery: String = app.private_backups.slots.path_for(0) + ".recovery-delete-ui"
		check(app.private_backups.slots.storage.write(recovery, VigilState.new().data), "Write recovery UI fixture")
		menu.show_backups()
		await press("DeleteRecoveryCopy")
		check(FileAccess.file_exists(recovery), "Opening confirmation preserves backup")
		await capture("delete-confirmation")
		await press("CancelConfirmation")
		check(FileAccess.file_exists(recovery), "Cancel preserves backup")
		await press("DeleteRecoveryCopy")
		await press("ConfirmAction")
		check(not FileAccess.file_exists(recovery), "Confirmed delete removes selected backup")
		check(button("DeleteRecoveryCopy") == null, "Deleted backup disappears from menu")
		var code := Build.encode(Build.capture("infinite", VigilState.new(), {}, "all", -1, {"enemies": ["basic"]}, "Delete UI build", ""))
		check(menu.slots.save_shared(code), "Write build UI fixture")
		menu.open_library(false)
		await press("DeleteBuild")
		await press("CancelConfirmation")
		check(menu.slots.shared_configurations("all").size() == 1, "Cancel preserves local build")
		await press("DeleteBuild")
		await press("ConfirmAction")
		check(menu.slots.shared_configurations("all").is_empty(), "Confirmed build deletion refreshes library")
	network = preload("res://tests/support/private_cloud_fixture.gd").new()
	root.add_child(network)
	network.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	network.refresh_token = "fixture"
	app.cloud = network
	app.private_backups.cloud = network
	var active: String = app.private_backups.slots.path_for(0)
	check(app.private_backups.slots.storage.write(active, VigilState.new().data), "Create cloud deletion UI fixture")
	await app.private_backups.sync_now()
	menu.show_backups()
	await press("DeleteCloudBackup")
	await press("CancelConfirmation")
	check(app.private_backups.remote_games.size() == 1, "Cancel keeps account backup")
	await press("DeleteCloudBackup")
	await press("ConfirmAction")
	check(app.private_backups.remote_games.is_empty() and FileAccess.file_exists(active), "Confirmed cloud deletion preserves local game")
	menu.library_community = true
	menu.page_view("library", "Community", menu.show_home)
	menu.library_entries = [{"id": "owned", "title": "Own upload", "author_id": network.player_id}, {"id": "other", "title": "Other upload", "author_id": "another-account"}]
	menu.show_library_entries()
	check(menu.content.find_children("DeleteBuild*", "Button", true, false).size() == 1, "Only owned Community uploads have Delete")
	network.queue_free()
	app.queue_free()
	await frames()
	print("BACKUP DELETE UI: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
