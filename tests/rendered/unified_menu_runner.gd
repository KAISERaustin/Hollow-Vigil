extends SceneTree
const Build = preload("res://scripts/persistence/reusable_build.gd")
var checks := 0
var failures: Array[String] = []
var app: VigilApp
var menu: Control
var network: Node
var toolbar_rects := {}

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 600)
	root.gui_embed_subwindows = true
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); push_error(text)

func frames() -> void:
	for i in 4: await process_frame

func button(key: String) -> BaseButton:
	for node in app.find_children(key, "BaseButton", true, false):
		if node.is_visible_in_tree(): return node
	return null

func press(key: String) -> void:
	await frames()
	var target := button(key)
	check(target != null, "Reachable action: " + key)
	if target == null: return
	if key in ["BackButton", "CampaignSavedGames", "CampaignBack", "GameMenuButton"] and target.text == "←":
		check_screen_back(target)
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(target)
		ancestor = ancestor.get_parent()
	await frames()
	var center := target.get_global_rect().get_center()
	if target.get_window() != root: center += Vector2(target.get_window().position)
	var motion := InputEventMouseMotion.new()
	motion.position = center
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await frames()
	for frame in 120:
		if not app.private_backups.busy and not app.public_builds.busy: break
		await process_frame
	await frames()

func open_game_menu() -> void:
	# Campaign's toolbar now returns to the map; exercise the full menu owner
	# directly here while saved_slot_continue_runner covers toolbar navigation.
	if is_instance_valid(app.campaign):
		app.show_game_menu()
		await frames()
	else:
		await press("GameMenuButton")

func fill(key: String, text: String) -> void:
	var entry: LineEdit = menu.find_child(key, true, false)
	check(entry != null, "Reachable field: " + key)
	if entry == null: return
	entry.text = text
	entry.text_changed.emit(text)

func choose(key: String, index: int) -> void:
	var picker: Button = menu.find_child(key, true, false)
	check(picker != null, "Reachable choice: " + key)
	if picker == null: return
	picker.select(index)
	picker.item_selected.emit(index)
	await frames()

func capture(key: String) -> void:
	await frames()
	var back := menu.header.get_node_or_null("BackButton") as Button
	if back != null: check_screen_back(back)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/unified-" + key + "-" + str(root.size.x) + ".png")
	var safe := Rect2(Vector2.ZERO, Vector2(root.size))
	check(safe.encloses(menu.card.get_global_rect()), "Page fits " + key)
	check(menu.scroll.get_global_rect().end.y <= menu.footer.get_global_rect().position.y + 1, "Actions stay below scrolling content: " + key)
	for node in menu.footer.get_children():
		if node is Control and node.visible: check(safe.encloses(node.get_global_rect()), "Pinned action fits " + key)

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://unified-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	menu.show_main_menu()
	await frames()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		toolbar_rects.clear()
		if is_instance_valid(network): network.refresh_token = ""
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames()
		for type in ["campaign", "infinite"]:
			menu.show_main_menu()
			await press("OpenCampaign" if type == "campaign" else "OpenInfinite")
			var expected_screen := "home" if type == "campaign" and dimensions.x == 360 else "slots"
			check(menu.screen == expected_screen and menu.game_type == type, "Infinite always opens saved games; Campaign opens home only for new players")
			if menu.screen == "slots":
				await press("BackButton")
				check(menu.screen == "main", "Saved games Back skips game home")
				menu.show_home(type)
			await capture(type + "-home")
			await press("Continue")
			check(menu.content.find_children("GameSlot?", "VBoxContainer", true, false).size() == 3, "Exactly three " + type + " slots")
			await capture(type + "-slots")
			await press("BackButton")
			check(menu.screen == "main", "Empty and occupied saved games return to main")
			menu.show_home(type)
			await press("NewGame")
			await press("ChooseCreative")
			await press("NextPlayStyle")
			check(menu.screen == "starting_build", "Play style precedes starting build")
			await capture(type + "-starting-build")
			await press("ReviewNewGame")
			fill("GameName", type.capitalize() + " " + str(dimensions.x))
			await choose("SaveSlotChoice", [360, 390, 540].find(dimensions.x) + 1)
			await capture(type + "-review")
			await press("StartGame")
			check(not menu.visible, "Start game opens " + type)
			if type == "campaign":
				check(is_instance_valid(app.campaign) and app.campaign.page == "map", "New Campaign opens World map")
				app.campaign.set_process(false)
				await press("CampaignLevel1")
				await press("BeginCampaignMission")
				await press("StartCampaignWave")
				remember_toolbar()
				app.campaign.run.tick(0.25)
				var held_run: RefCounted = app.campaign.run
				var held_time: float = held_run.wave_time
				await open_game_menu()
				await capture(type + "-game-menu")
				check(app.campaign.paused, "Menu pauses Campaign")
				await press("BackButton")
				check(app.campaign.run == held_run and app.campaign.run.wave_time == held_time, "Resume holds live wave without restarting")
				await open_game_menu()
			else:
				compare_toolbar()
				await open_game_menu()
				check(app.game.suspended, "Menu pauses Infinite")
				await capture(type + "-game-menu")
				await press("CreativeTools")
				check(menu.screen == "creative_tools" and button("AddMillionGold") != null, "Infinite Creative retains its tools")
				await press("BackButton")
			await press("SaveBuild")
			if type == "campaign":
				await choose("BuildScope", 1)
				check(menu.form.scope == "level" and menu.form.level == 0, "This-level build scope remains explicit")
				await choose("BuildScope", 0)
			await capture(type + "-save-build")
			check(menu.content.find_children("Contents_*", "CheckBox", true, false).size() == (1 if type == "campaign" else 2), "Save build offers only applicable content options")
			check(button("Contents_rules").button_pressed, "Rules start selected")
			check(button("Contents_layout") == null if type == "campaign" else button("Contents_layout").button_pressed, "Only Infinite offers selected layouts and equipment")
			check(menu.form.contents == Build.all_contents(type), "Default selection saves every registered content type")
			check(menu.content.find_child("IncludedContentsSummary", true, false) == null and button("SelectAllContents") == null and button("ExpandContents_enemies") == null, "Save build omits detailed selectors and included contents")
			fill("BuildName", type.capitalize() + " rules " + str(dimensions.x))
			await press("Contents_rules")
			if type == "infinite":
				check(menu.form.contents == {"layout": true, "terrain": true}, "Layout, equipment and explored tiles toggle together without rules")
				check(not menu.prepared_form().is_empty(), "Infinite layout option alone produces a valid build")
				await press("Contents_layout")
			await press("SavePrivately")
			check(menu.form.contents.is_empty() and menu.form_saved_code.is_empty(), "An empty selection cannot create a private build")
			await press("Contents_rules")
			var selected_rules: Dictionary = menu.form.contents.duplicate(true)
			for category in Build.STAT_GROUPS:
				check(selected_rules[category] == Build.all_contents(type)[category], "Rules select every " + category + " type")
			check(selected_rules.get("resources", false) and not selected_rules.has("layout") and not selected_rules.has("terrain"), "Rules include starting resources without layout or explored tiles")
			if type == "campaign": check(selected_rules.get("timing", false) and selected_rules.get("composition", false) and selected_rules.get("rewards", false), "Campaign rules include all wave settings")
			await press("SavePrivately")
			check(not menu.form_saved_code.is_empty(), "Private save succeeds offline for " + type)
			check(Build.decode(menu.form_saved_code).contents == selected_rules, "Saved build round trip retains the complete rules group")
			await press("ShareToCommunity")
			check(menu.screen == "account", "Share requests account on the shared account page")
			await capture(type + "-account")
			await press("AccountDone")
			check(menu.screen == "save_build" and menu.form.contents == selected_rules, "Account round trip preserves prepared contents")
			await press("BackButton")
			await check_rules(type)
			await press("GameSettings")
			check(button("CreativeTools") == null, "Shared settings omit Creative tools in " + type)
			await capture(type + "-settings")
			await press("SettingsSound")
			await capture(type + "-sound")
			await press("BackButton")
			await press("BackButton")
			await press("ExitGame")
			check(menu.screen == ("slots" if type == "infinite" else "home") and menu.game_type == type, "Exit opens Infinite saved games or Campaign home")
			if type == "campaign": await press("Continue")
			await press("ContinueGameSlot" + str([360, 390, 540].find(dimensions.x) + 1))
			if type == "campaign":
				app.campaign.set_process(false)
				check(app.campaign.page == "map", "Continue opens Campaign map before resuming a level")
				await press("CampaignLevel1")
				check(app.campaign.page == "battle" and app.campaign.run.wave_time < 1.0, "Choosing saved level reconstructs Campaign from wave start")
			await open_game_menu()
			await press("ExitGame")
			if type == "infinite":
				await press("BackButton")
				check(menu.screen == "main", "Back after Infinite exit returns to main")
				menu.show_home(type)
			await press("MyBuilds")
			await capture(type + "-library")
			await press("BuildDetails")
			await capture(type + "-detail")
			await press("UseBuild")
			check(menu.screen == "play_style" and not menu.new_game.entry.is_empty(), "Home library starts New game with chosen build")
			menu.show_home(type)
		await extended_workflows()
	print("UNIFIED_MENU: %d checks, %d failures" % [checks, failures.size()])
	app.game.suspended = true
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func check_rules(type: String) -> void:
	await press("EditRules")
	check(menu.screen == "rules", "Shared rules page opens in " + type)
	await capture(type + "-rules")
	var prior: Dictionary = app.campaign.level_setup(0).overrides.duplicate(true) if type == "campaign" else app.game.tuning.duplicate(true)
	await press("EnemiesCategory")
	menu.rules_editor.find_child("hpValue", true, false).value = 777
	await press("BackButton")
	check(menu.screen == "rules" and menu.rules_editor.category_list.visible and menu.editor_game.tuning.enemies.basic.hp == 777, "Back returns from type editor while retaining draft")
	await press("CancelRules")
	await press("CancelConfirmation")
	check(menu.screen == "rules", "Cancel confirmation leaves rule draft available")
	await press("CancelRules")
	await press("ConfirmAction")
	check((app.campaign.level_setup(0).overrides if type == "campaign" else app.game.tuning) == prior, "Discard leaves live rules unchanged")
	await press("EditRules")
	await press("EnemiesCategory")
	menu.rules_editor.find_child("hpValue", true, false).value = 888
	await press("ApplyRules")
	check(app.campaign.level_setup(0).overrides.tuning.enemies.basic.hp == 888 if type == "campaign" else app.game.tuning.enemies.basic.hp == 888, "Apply commits rules to only the selected session")
	check(menu.screen == "game_menu", "Rules return to held game menu")

func check_screen_back(back: Button) -> void:
	check(back != null, "Back is present on the current screen")
	if back == null: return
	var inset := 8 if is_instance_valid(app.campaign) and app.campaign.page == "battle" and back == app.campaign.game_toolbar.menu_button else 12
	check(back.get_global_rect().is_equal_approx(Rect2(inset, inset, 48, 48)), "Back keeps its screen's size and inset on %s at %s: %s" % [back.name, root.size, back.get_global_rect()])
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := back.get_theme_stylebox(state)
		check(style.get_content_margin(SIDE_LEFT) == 12 and style.get_content_margin(SIDE_RIGHT) == 12 and style.get_content_margin(SIDE_TOP) == 8 and style.get_content_margin(SIDE_BOTTOM) == 8, "Back keeps symmetric padding in " + state)

func remember_toolbar() -> void:
	for key in ["PauseButton", "SpeedButton"]:
		var control := button(key)
		check(control != null, "Shared Campaign toolbar control " + key)
		if control != null: toolbar_rects[key] = control.get_global_rect()

func compare_toolbar() -> void:
	for key in toolbar_rects:
		var control := button(key)
		check(control != null and control.get_global_rect().is_equal_approx(toolbar_rects[key]), "Matching toolbar position and size in both game types: " + key)

func install_network() -> void:
	if is_instance_valid(network): return
	var previous: Node = app.cloud
	network = preload("res://tests/support/private_cloud_fixture.gd").new()
	network.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	network.refresh_token = "fixture"
	network.display_name = "Fixture player"
	app.add_child(network)
	app.cloud = network
	app.public_builds.cloud = network
	app.private_backups.cloud = network
	app.campaign_backup.cloud = network
	previous.queue_free()

func extended_workflows() -> void:
	install_network()
	network.refresh_token = "fixture"
	# Library selection from New game must retain its already selected play style.
	menu.show_home("infinite")
	await press("NewGame")
	await press("ChooseSurvival")
	await press("NextPlayStyle")
	await press("ChooseMyBuilds")
	await press("BuildDetails")
	await press("UseBuild")
	check(menu.screen == "starting_build" and menu.new_game.mode == "survival", "Library return preserves chosen play style")
	await press("ReviewNewGame")
	fill("GameName", "Survival replacement")
	await choose("SaveSlotChoice", 1)
	if menu.new_game.entry.build.game_type == "campaign": await choose("LevelChoice_source_level", 1)
	var previous: Dictionary = menu.slots.summary(0)
	await press("StartGame")
	await press("CancelConfirmation")
	check(menu.slots.summary(0) == previous, "Cancel replacement preserves occupied slot")
	await press("StartGame")
	await capture("replacement-confirmation")
	await press("ConfirmAction")
	await open_game_menu()
	check(button("EditRules") == null, "Survival cannot edit rules or apply another build")
	await press("GameSettings")
	menu.show_creative_tools()
	check(menu.screen == "settings", "Survival rejects direct Creative tools navigation")
	check(button("CreativeTools") == null, "Survival settings omit Creative tools")
	await press("BackButton")
	await press("ExitGame")
	check(menu.screen == "slots" and not app.slot_active and app.game.suspended, "Infinite Survival exits directly to saved games with the session stopped")
	check(app.private_backups.recovery_games().size() > 0, "Replacement is browsable in Recovery copies")
	# Share failure leaves the prepared form and private copy available for Retry.
	menu.show_home("infinite")
	await press("MyBuilds")
	await press("BuildDetails")
	await press("SharePrivateBuild")
	network.unavailable = true
	await press("ShareToCommunity")
	check(button("RetryShare") != null and not menu.form_saved_code.is_empty(), "Failed public share keeps a private copy and explicit Retry")
	network.unavailable = false
	network.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	network.generation += 1
	await press("RetryShare")
	check(menu.pending_publish.is_empty() and not network.publications.is_empty(), "Explicit Retry publishes prepared contents under the current account after an account switch")
	menu.show_home("infinite")
	network.unavailable = true
	await press("Community")
	check(button("RetryCommunity") != null, "Community connection failure offers Retry")
	network.unavailable = false
	await press("RetryCommunity")
	# Drive both pagination directions through the real library controls.
	# Pagination needs distinct entries, not 21 copies of every Campaign rule.
	var pagination := Build.capture("infinite", VigilState.new(), {}, "all", -1, {"enemies": ["basic"]}, "Pagination fixture", "")
	var sample: Dictionary = JSON.parse_string(Build.encode(pagination))
	for index in 21:
		var payload: Dictionary = JSON.parse_string(sample.payload)
		payload.setup.name = "Community page fixture " + str(index)
		var payload_text := JSON.stringify(payload)
		network.publications["page-fixture-" + str(index)] = {"format": Build.FORMAT, "payload": payload_text, "checksum": payload_text.sha256_text()}
	await press("RefreshCommunity")
	check(button("PreviousBuilds").disabled and not button("NextBuilds").disabled, "Community page controls match available results")
	await press("NextBuilds")
	check(menu.library_page == 1 and not button("PreviousBuilds").disabled, "Next opens another Community page")
	await press("PreviousBuilds")
	await press("BuildDetails")
	await capture("community-detail")
	var slots_before: Array = []
	for slot in 3: slots_before.append(menu.slots.summary(slot))
	await press("SaveCommunityPrivately")
	for slot in 3: check(menu.slots.summary(slot) == slots_before[slot], "Community private copy does not consume a playable slot")
	menu.show_home("campaign")
	await press("Backups")
	await press("BackUpNow")
	await capture("backups")
	check(app.private_backups.remote_games.size() == ([360, 390, 540].find(root.size.x) + 1) * 2, "Back up now includes every occupied slot in both modes")
	await press("RestoreBackup")
	await capture("restore-destination")
	await press("RestoreIntoSlot1")
	await capture("restore-comparison")
	var local_before: Dictionary = menu.campaign_slots.summary(0)
	await press("KeepDeviceVersion")
	check(menu.screen == "slots" and menu.campaign_slots.summary(0) == local_before, "Keep local returns to Saved games without restoring")
	menu.show_backups(menu.show_home)
	await press("RestoreBackup")
	await press("RestoreIntoSlot1")
	await press("UseCloudVersion")
	await press("CancelConfirmation")
	check(menu.campaign_slots.summary(0) == local_before, "Cancel restore leaves local version intact")
	await press("UseCloudVersion")
	await press("ConfirmAction")
	check(menu.screen == "slots" and menu.campaign_slots.summary(0).id == local_before.id, "Confirmed restore keeps selected game identity")
	# Omitted map data and explicit cross-mode level choices remain visible in Review.
	var portable := Build.capture("infinite", VigilState.new(), {}, "all", -1, {"enemies": ["basic"]}, "Portable stats", "")
	menu.show_home("campaign")
	menu.begin_new(-1, menu.slots.reusable_entry(menu.slots.shared_entry(Build.encode(portable))))
	await press("ChooseSurvival")
	await press("NextPlayStyle")
	await press("ReviewNewGame")
	check(not menu.prepare_new().ok, "Portable Campaign stats require explicit affected scope")
	await choose("ApplyStatsTo", 2)
	check(not menu.prepare_new().ok, "One-level stats require explicit level")
	await choose("LevelChoice_target_level", 3)
	check(menu.prepare_new().levels.keys() == ["2"], "Selected stat contents affect only the chosen Campaign level")
	await capture("portable-review")
	if root.size.x == 540:
		fill("GameName", "Survival campaign")
		await choose("SaveSlotChoice", 3)
		var siblings: Array = [menu.campaign_slots.summary(0), menu.campaign_slots.summary(1)]
		await press("StartGame")
		await press("ConfirmAction")
		app.campaign.set_process(false)
		check(button("CampaignLevel3").disabled and app.campaign.mode == "survival", "Using a one-level build does not unlock Survival levels")
		await press("CampaignLevel1")
		await press("BeginCampaignMission")
		await open_game_menu()
		check(button("EditRules") == null, "Campaign Survival cannot edit rules")
		await press("ExitGame")
		check(menu.campaign_slots.summary(0) == siblings[0] and menu.campaign_slots.summary(1) == siblings[1], "New Campaign in a full slot preserves the other Campaign games")
	menu.show_main_menu()
