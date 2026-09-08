extends SceneTree
## Back must belong to its source page and advance at most once per input batch.
const Harness = preload("res://tests/rendered/visual_smoke.gd")
var app: VigilApp
var menu: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Input.emulate_mouse_from_touch = true
	root.gui_embed_subwindows = true
	preload("res://tests/support/timeout.gd").arm(self, 240)
	call_deferred("run")

func settle() -> void:
	for frame in 6: await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func press(owner: Node, key: String) -> void:
	await settle()
	var target := owner.find_child(key, true, false) as BaseButton
	check(is_instance_valid(target) and target.is_visible_in_tree(), "Visible navigation target: " + key)
	if not is_instance_valid(target): return
	var parent := target.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await settle()
	await Harness.tap(app, target.get_global_rect().get_center(), true)
	await settle()

func system_back() -> void:
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()

func key_back() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://back-navigation-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.audio.set_suspended(true)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	Engine.max_fps = 120
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for mode in ["creative", "survival"]:
			print("BACK NAVIGATION: %s at %s" % [mode, dimensions])
			menu.campaign_slots.base_path = app.game.save_path + "." + str(dimensions.x) + mode
			var saved: Dictionary = menu.campaign_slots.create(0, mode, "Navigation " + mode)
			app.open_campaign_slot(0, saved)
			var campaign: Control = app.campaign
			campaign.set_process(false)
			await settle()
			for cycle in 3:
				await press(campaign, "CampaignMapMenu")
				await press(menu, "GameSettings")
				await press(menu, "SettingsSound")
				await press(menu, "BackButton")
				check(menu.screen == "settings", "Sound Back returns only to Settings")
				await key_back()
				check(menu.screen == "game_menu", "Keyboard Back returns only to Campaign menu")
				await system_back()
				check(not menu.visible and app.campaign == campaign and campaign.page == "map", "Menu Back resumes the same Campaign")
			await press(campaign, "CampaignMapMenu")
			await press(menu, "GameBackups")
			await press(menu, "BackupAccount")
			await system_back()
			check(menu.screen == "backups", "Account returns to its Backups caller")
			await press(menu, "BackButton")
			check(menu.screen == "game_menu", "Backups returns to its Campaign caller")
			await press(menu, "GameSettings")
			await press(menu, "SettingsSound")
			var stale: Button = menu.header.get_node("BackButton")
			stale.pressed.emit()
			stale.pressed.emit()
			check(menu.screen == "settings", "A detached Sound Back cannot pop the replacement Settings page")
			await settle()
			menu.show_sound()
			await settle()
			for duplicate in 3: app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
			check(menu.visible and menu.screen == "settings" and app.campaign == campaign, "Queued system Back advances one page without exiting Campaign")
			await settle()
			menu.resume_game()
			var hidden_screen: String = menu.screen
			menu.go_back()
			check(not menu.visible and menu.screen == hidden_screen, "A hidden menu cannot process a late Back callback")
			menu.open_game_menu()
			menu.show_settings(menu.open_game_menu)
			menu.show_sound()
			await settle()
			var point: Vector2 = menu.header.get_node("BackButton").get_global_rect().get_center()
			# Mobile input can arrive buffered after a slow frame. Send two full
			# physical touch sequences before the replacement page has settled.
			for tap in 2:
				for down in [true, false]:
					var touch := InputEventScreenTouch.new()
					touch.position = point
					touch.pressed = down
					Input.parse_input_event(touch)
			await settle()
			check(menu.visible and menu.screen == "settings", "Buffered touch Back cannot skip Settings")
			menu.resume_game()
			campaign.start_mission(0)
			await settle()
			await press(campaign.game_toolbar, "GameMenuButton")
			check(campaign.page == "map" and app.campaign == campaign, "Battle Back returns to map without closing the save")
			campaign.show_playthrough_picker()
			await settle()
			await key_back()
			check(not menu.visible and app.campaign == campaign and campaign.page == "map", "Campaign build picker Back uses its own header route")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/back-navigation-%s-%d.png" % [mode, dimensions.x])
			await press(campaign, "CampaignSavedGames")
			check(menu.visible and menu.screen == "slots" and not is_instance_valid(app.campaign), "Map Back opens saved games")
			await system_back()
			check(menu.screen == "main", "A separate Saved games Back returns to main")
		# The same shared Back handling also protects Infinite and main settings.
		menu.show_main_menu()
		menu.show_settings(menu.show_main_menu)
		await settle()
		await press(menu, "SettingsSound")
		await system_back()
		await system_back()
		check(menu.screen == "main", "Main settings return to main after separate Back actions")
		menu.open_mode("infinite")
		await settle()
		await press(menu, "NewGameSlot3")
		await system_back()
		check(menu.screen == "slots", "New Infinite game cancels to saved games")
	var prefix := app.game.save_path.get_file()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(prefix): DirAccess.remove_absolute("user://" + filename)
	print("BACK_NAVIGATION: %d checks, %d failures; touch, keyboard, system Back and duplicate events at three portrait sizes" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
