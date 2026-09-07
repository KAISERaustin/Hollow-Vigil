extends SceneTree

const Build = preload("res://scripts/persistence/reusable_build.gd")
const Run = preload("res://scripts/campaign/run.gd")
var checks := 0
var failures := 0
var app: VigilApp
var menu: Control
var network: Node

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 600)
	root.gui_embed_subwindows = true
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for index in 4: await process_frame

func button(key: String) -> BaseButton:
	for node in app.find_children(key, "BaseButton", true, false):
		if node.is_visible_in_tree(): return node
	return null

func press(key: String) -> void:
	await frames()
	var target := button(key)
	check(target != null, "Reachable action: " + key)
	if target == null: return
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(target)
		ancestor = ancestor.get_parent()
	await frames()
	var center := target.get_global_rect().get_center()
	if target.get_window() != root: center += Vector2(target.get_window().position)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await frames()

func choose(key: String, index: int) -> void:
	await press(key)
	await press("Choice_" + str(index))

func capture(key: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign-map-menu-%s-%dx%d.png" % [key, root.size.x, root.size.y])
	if menu.visible:
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(menu.card.get_global_rect()), "Menu page fits " + key)
		check(menu.scroll.get_global_rect().end.y <= menu.footer.global_position.y + 1, "Footer remains outside scroll area: " + key)

func check_campaign_settings(key: String) -> void:
	check(button("CreativeTools") == null, "Campaign menu omits Creative tools: " + key)
	await press("GameSettings")
	var run_before: RefCounted = app.campaign.run
	var gold_before: float = run_before.game.data.balance if run_before != null else 0.0
	menu.show_creative_tools()
	await frames()
	check(menu.screen == "settings", "Campaign rejects direct Creative tools navigation: " + key)
	check(button("CreativeTools") == null and button("AddMillionGold") == null, "Campaign settings have no gold grant: " + key)
	check(app.campaign.run == run_before, "Settings preserve the Campaign run: " + key)
	if run_before != null:
		check(run_before.game.data.balance == gold_before, "Settings preserve Campaign gold: " + key)
	check(button("SettingsAccount") != null and button("SettingsSound") != null, "Campaign retains Account and Sound: " + key)
	await capture(key + "-settings")
	await press("BackButton")
	check(menu.screen == "game_menu", "Settings return to Campaign menu: " + key)

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://map-menu-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	var previous: Node = app.cloud
	network = preload("res://tests/support/private_cloud_fixture.gd").new()
	network.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	network.refresh_token = "fixture"
	network.display_name = "Map menu fixture"
	app.add_child(network)
	app.cloud = network
	app.public_builds.cloud = network
	app.private_backups.cloud = network
	app.private_backups.enabled = false
	app.campaign_backup.cloud = network
	previous.queue_free()
	for viewport in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960), Vector2i(844,390)]:
		root.size = viewport
		root.content_scale_size = viewport
		menu.campaign_slots.base_path = app.game.save_path + "-" + str(viewport.x)
		menu.campaign_slots.create(2, "creative", "Other slot")
		var sibling: Dictionary = menu.campaign_slots.summary(2)
		for mode in ["creative", "survival"]:
			network.refresh_token = ""
			print("CAMPAIGN MAP MENU: %s at %dx%d" % [mode, viewport.x, viewport.y])
			var slot := 0 if mode == "creative" else 1
			var saved: Dictionary = menu.campaign_slots.create(slot, mode, "OG Testing " + mode.capitalize(), {"0": {"overrides": {"gold": 777}}})
			var checkpoint_run := Run.new(0, {"gold": 777}, mode)
			check(checkpoint_run.build(checkpoint_run.mission.sockets[0].index, "rapid"), "Place a checkpoint tower")
			saved.checkpoint = checkpoint_run.checkpoint()
			check(menu.campaign_slots.save_slot(slot, saved), "Persist checkpoint fixture")
			app.open_campaign_slot(slot, saved)
			var campaign: Control = app.campaign
			campaign.set_process(false)
			await frames()
			check(campaign.page == "map" and campaign.run == null, "Continue reaches map before creating a run")
			var header_button := button("CampaignMapMenu")
			var header_rect := header_button.get_global_rect()
			check(header_rect.size.y >= 48 and header_rect.end.x <= viewport.x - 12, "Menu has a phone-sized target at the top right")
			check(header_rect.size == Vector2(76,48), "Menu remains a horizontal 76 by 48 button")
			check(campaign.map_navigation.get_global_rect().encloses(header_rect), "Menu fits within the fixed header")
			var heading: Label = campaign.map_heading.get_child(0).get_child(1)
			check(heading.get_global_rect().end.x <= header_rect.position.x, "Long slot name leaves room for Menu")
			check(campaign.map_navigation.get_global_rect().encloses(heading.get_global_rect()), "Slot title fits above the header divider")
			await capture(mode + "-map")
			campaign.page_scroll.scroll_vertical = 310
			await frames()
			var scroll_position: int = campaign.page_scroll.scroll_vertical
			check(header_button.get_global_rect() == header_rect, "Menu stays fixed when the map scrolls")
			await press("CampaignMapMenu")
			check(menu.screen == "game_menu" and menu.game_type == "campaign", "Map opens the selected Campaign menu")
			check((button("EditRules") != null) == (mode == "creative"), "Rule editing follows the slot mode")
			await capture(mode + "-menu")
			await check_campaign_settings(mode + "-map")
			if mode == "creative":
				await press("EditRules")
				check(button("EditLevel1") == null, "Campaign rules omit the level list")
				await press("EnemiesCategory")
				menu.rules_editor.inputs.hp.value = 999
				await press("ApplyRules")
				check(campaign.level_setup(0).overrides.tuning.enemies.basic.hp == 999 and campaign.level_setup(29).overrides.tuning.enemies.basic.hp == 999 and campaign.run == null, "Map rule editing reaches the whole campaign without starting a mission")
			await press("SaveBuild")
			check(menu.form.scope == "all" and menu.form.level == -1, "Map defaults to a whole campaign export")
			var name_field: LineEdit = menu.find_child("BuildName", true, false)
			name_field.text = "Map export " + mode
			name_field.text_changed.emit(name_field.text)
			var whole: Dictionary = menu.prepared_form()
			check(whole.data.levels.size() == Build.Configuration.Catalog.COUNT, "Whole campaign includes every level")
			check(button("Contents_layout") == null and not whole.contents.has("layout"), "Campaign has no layout or equipment export option")
			for level in whole.data.levels.values(): check(not level.has("layout"), "Campaign export excludes every placed layout")
			check(whole.data.levels["0"].resources.gold == 777, "Global stat edits preserve starting resources in exports")
			check(not whole.has("checkpoint") and not whole.has("completed"), "Portable export excludes saved progression")
			check(campaign.campaign_save.checkpoint.state.towers.size() == 1, "Export composition does not mutate checkpoint state")
			await press("SavePrivately")
			check(not menu.form_saved_code.is_empty(), "Map export saves privately")
			await capture(mode + "-export")
			await choose("BuildScope", 1)
			check(menu.form.scope == "level" and menu.prepared_form().is_empty(), "One-level export requires an explicit level")
			await press("SavePrivately")
			check(menu.message.text == "Choose a level before saving.", "Missing level has an actionable error")
			await choose("BuildLevel", 30)
			var single: Dictionary = menu.prepared_form()
			check(single.level == 29 and single.data.levels.keys() == ["29"], "The final level can be exported independently")
			check(not menu.prepared_form().contents.has("layout"), "Rules-only export omits layouts")
			await capture(mode + "-one-level")
			var publications_before: int = network.publications.size()
			network.refresh_token = "fixture"
			await press("ShareToCommunity")
			check(network.publications.size() == publications_before + 1 and menu.pending_publish.is_empty(), "Explicit Community action publishes through the fixture service")
			await press("BackButton")
			await press("BackButton")
			check(not menu.visible and not menu.held and campaign.page == "map" and campaign.run == null, "Back returns to the same map")
			check(campaign.page_scroll.scroll_vertical == scroll_position, "Returning preserves map scroll")
			# Export excludes placements even when the live run has newer towers.
			campaign.show_briefing(0)
			check(campaign.run.build(campaign.run.mission.sockets[1].index, "rapid"), "Place a second tower in the resumed run")
			check(campaign.run.start_wave(), "Start a checkpointed wave")
			check(campaign.run.build(campaign.run.mission.sockets[2].index, "rapid"), "Place a tower after the wave checkpoint")
			app.show_game_menu()
			await frames()
			await check_campaign_settings(mode + "-battle")
			menu.resume_game()
			campaign.show_map()
			await press("CampaignMapMenu")
			await press("SaveBuild")
			menu.form.name = "Latest placement"
			check(not menu.prepared_form().data.levels["0"].has("layout"), "Returning from battle still exports only Campaign content")
			check(campaign.run.game.data.towers.size() == 3, "Content export preserves all live placements")
			check(campaign.campaign_save.checkpoint.state.towers.size() == 2, "Export does not rewrite the wave-start checkpoint")
			menu.resume_game()
			campaign.close()
			await frames()
			check(menu.campaign_slots.summary(2) == sibling, "Export and edits preserve sibling slots")
	app.game.suspended = true
	app.queue_free()
	await frames()
	print("CAMPAIGN MAP MENU: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
