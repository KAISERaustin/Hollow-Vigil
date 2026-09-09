extends SceneTree
## Real viewport touch events, isolated saved slots, and every Campaign menu.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
var app: VigilApp
var campaign: Control
var checks := 0
var failures: Array[String] = []
var viewports_checked := 0

func _initialize() -> void:
	Input.emulate_mouse_from_touch = true
	# Advertise touchscreen capability on the Windows validation host, as on phones.
	Input.emulate_touch_from_mouse = true
	root.gui_embed_subwindows = true
	preload("res://tests/support/timeout.gd").arm(self, 600)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 6: await process_frame
	if is_instance_valid(campaign) and is_instance_valid(campaign.board):
		for frame in 160:
			if not campaign.board.camera_framing.active: break
			await process_frame

func finger(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = index
	Input.parse_input_event(event)
	await process_frame

func tap_at(point: Vector2) -> void:
	await finger(point, true)
	await finger(point, false)
	await settle()

func press(target: BaseButton) -> void:
	check(is_instance_valid(target), "Touch action exists")
	if not is_instance_valid(target): return
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(target)
		ancestor = ancestor.get_parent()
	await settle()
	var rect := target.get_global_rect()
	if target.get_window() != root: rect.position += Vector2(target.get_window().position)
	check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(rect), "Touch target fits: " + target.name)
	await tap_at(rect.get_center())

func named(key: String) -> BaseButton:
	for node in app.find_children(key, "BaseButton", true, false):
		if node.is_visible_in_tree(): return node
	return null

func swipe(point: Vector2, amount: Vector2, index: int = 0) -> void:
	await finger(point, true, index)
	for step in 10:
		var event := InputEventScreenDrag.new()
		event.index = index
		event.position = point + amount * float(step + 1) / 10.0
		event.relative = amount / 10.0
		Input.parse_input_event(event)
		await process_frame
	await finger(point + amount, false, index)
	await settle()

func back() -> void:
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/mobile-campaign-%s-%dx%d.png" % [label, root.size.x, root.size.y])

func audit(owner: Control, context: String) -> void:
	await settle()
	for node in owner.find_children("*", "BaseButton", true, false):
		if not node.is_visible_in_tree() or node.get_viewport() != root: continue
		var ancestor := node.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(node)
			ancestor = ancestor.get_parent()
		await settle()
		var rect: Rect2 = node.get_global_rect()
		check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(rect), context + " reachable " + node.name)
		check(rect.size.x >= UI.TARGET - 0.1 and rect.size.y >= UI.TARGET - 0.1, context + " 48-unit target " + node.name)

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://mobile-campaign-controls-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.audio.set_suspended(true)
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	check(app.show_save_slots(), "Open isolated save menu: " + app.game.save_error)
	if not is_instance_valid(app.slot_menu):
		quit(1)
		return
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		if "--quick" in OS.get_cmdline_user_args() and dimensions != Vector2i(360, 640): continue
		viewports_checked += 1
		root.size = dimensions
		root.content_scale_size = dimensions
		app.slot_menu.campaign_slots.base_path = app.game.save_path + ".campaign-" + str(dimensions.x)
		var saved: Dictionary = app.slot_menu.campaign_slots.create(0, "creative", "Mobile Campaign audit")
		app.open_campaign_slot(0, saved)
		campaign = app.campaign
		campaign.set_process(false)
		await settle()
		print("MOBILE CAMPAIGN: %s" % str(dimensions))
		await map_and_briefing()
		print("MOBILE CAMPAIGN: map and briefing checked")
		await battle_menus()
		print("MOBILE CAMPAIGN: battle menus checked")
		await result_routes()
		if is_instance_valid(campaign): campaign.close()
		await settle()
	var prefix: String = app.game.save_path.get_file()
	app.queue_free()
	await process_frame
	await process_frame
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(prefix): DirAccess.remove_absolute("user://" + filename)
	print("MOBILE CAMPAIGN CONTROLS: %d checks, %d failures; %d map levels, %d portrait sizes, touch menus/scroll/pan/pinch/modal shielding/Android Back" % [checks, failures.size(), Catalog.COUNT, viewports_checked])
	quit(0 if failures.is_empty() else 1)

func map_and_briefing() -> void:
	await settle()
	var scroll: ScrollContainer = campaign.page_scroll
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Opening map computes its scrolling range")
	campaign.show_map()
	await settle()
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Refreshing map retains its scrolling range")
	await swipe(scroll.get_global_rect().get_center(), Vector2(0, -160))
	check(scroll.scroll_vertical > 40 and campaign.page == "map", "Map swipe scrolls without entering a level: scroll=%d page=%s" % [scroll.scroll_vertical, campaign.page])
	await audit(campaign.page_scroll, "All map markers")
	await capture("map")
	var indices: Array = range(Catalog.COUNT) if root.size.x == 390 else [0, Catalog.COUNT - 1]
	for index in indices:
		await press(named("CampaignLevel%d" % (index + 1)))
		check(campaign.page == "briefing" and campaign.run.mission.index == index, "Touch opens authored level %d" % (index + 1))
		await audit(campaign.page_scroll, "Briefing %d" % (index + 1))
		await back()
		check(campaign.page == "map", "Briefing Back returns to map")
	await press(named("CampaignLevel1"))
	await press(named("PreviewCampaignWaves"))
	check(campaign.dialog.visible and campaign.waves_dialog, "Briefing previews Waves by touch")
	await back()
	check(not campaign.dialog.visible and campaign.page == "briefing", "Preview Back retains briefing")
	await press(named("BeginCampaignMission"))
	check(campaign.page == "battle" and campaign.run.phase == "planning", "Begin level starts the selected level")

func battle_menus() -> void:
	campaign.game.data.balance = 1000000
	await audit(campaign.game_toolbar, "Battle toolbar")
	for expected in [2.0, 4.0, 1.0]:
		await press(campaign.speed_button)
		check(campaign.speed == expected, "Touch cycles speed once")
	await press(campaign.pause_button)
	check(campaign.paused, "Touch explicitly pauses")
	await press(campaign.pause_button)
	check(not campaign.paused, "Touch explicitly resumes")
	await press(named("CampaignWaves"))
	await wave_menus()
	await press(named("CloseCampaignDialog"))
	# Ground placement's complete finger flow is covered by ground_build_runner.
	# Set up a tower here to audit the current shared management menus.
	var socket: Dictionary = campaign.run.mission.sockets[0]
	campaign.run.build(socket.index, "rapid")
	var id: String = campaign.run.tower_at(socket.index)
	check(not id.is_empty(), "Campaign tower fixture builds")
	if id.is_empty(): return
	await tower_menus(socket, id)
	await map_gestures()
	await press(named("StartCampaignWave"))
	check(campaign.run.phase == "wave", "Start wave touch starts combat")
	await press(named("CampaignWaves"))
	var before: float = campaign.run.wave_time
	campaign._process(0.1)
	check(campaign.run.wave_time > before and not campaign.paused, "Waves keeps combat running")
	await back()
	await back()
	check(campaign.dialog.visible and named("ConfirmCampaignExit") != null, "Battle Back asks before exiting")
	await audit(campaign.dialog_card, "Exit level")
	await press(named("ConfirmCampaignExit"))
	check(campaign.page == "briefing" and not app.slot_menu.visible, "Confirmed exit returns to briefing")
	await back()
	check(campaign.page == "map", "Briefing Back returns to map")

func wave_menus() -> void:
	var scroll := campaign.dialog_body.get_parent() as ScrollContainer
	await swipe(scroll.get_global_rect().get_center(), Vector2(0, -100))
	check(scroll.scroll_vertical > 0 and campaign.waves_dialog, "Waves swipe scrolls without opening details")
	await audit(campaign.dialog_card, "Waves")
	await capture("waves")
	for index in campaign.run.mission.waves.size():
		await press(named("WaveBalancingDetails%d" % (index + 1)))
		check(campaign.dialog_title.text == "Wave %d balancing" % (index + 1), "Wave detail opens by touch")
		await audit(campaign.dialog_card, "Wave details")
		await back()
		check(campaign.waves_dialog and campaign.dialog.visible, "Wave detail system Back returns to Waves")
	await press(named("EditCampaignWave1"))
	check(app.slot_menu.visible and app.slot_menu.rules_editor != null, "Edit wave opens the shared editor")
	await press(named("CampaignGroupKind0"))
	var picker: Button = app.slot_menu.find_child("CampaignGroupKind0", true, false)
	check(picker.get_popup().visible, "Touch opens spawn type picker")
	await back()
	check(not picker.get_popup().visible and app.slot_menu.visible, "Back dismisses only the spawn picker")
	await press(picker)
	await press(named("Choice_1"))
	check(picker.selected == 1 and not picker.get_popup().visible, "Touch chooses a wave spawn type")
	var chosen_kind: String = picker.get_item_metadata(1)
	var reward: SpinBox = app.slot_menu.find_child("CampaignWaveReward", true, false)
	var old_reward := reward.value
	await press(reward.get_parent().get_child(1).get_child(1))
	check(reward.value == old_reward + reward.step, "Touch changes wave reward exactly once")
	await audit(app.slot_menu.card, "Wave editor")
	await press(named("ApplyRules"))
	check(not app.slot_menu.visible and campaign.dialog.visible and campaign.waves_dialog, "Apply wave returns to Waves")
	check(campaign.run.mission.waves[0][0][0] == chosen_kind and campaign.run.mission.wave_rules[0].reward == old_reward + 1, "Touch applies selected spawn type and reward to gameplay")

func tower_menus(socket: Dictionary, id: String) -> void:
	var tower: Dictionary = campaign.game.data.towers[id]
	for action in ["target", "equipment", "sell", "move"]:
		campaign.show_socket(socket.index)
		await settle()
		await press(named("Manage_" + action))
		check(campaign.tower_dialog.visible and campaign.tower_dialog.mode == action, "Touch opens tower " + action)
		await audit(campaign.tower_dialog.card, "Tower " + action)
		var balance: float = campaign.game.data.balance
		await tap_at(Vector2(4, campaign.board.global_position.y + 8))
		check(campaign.tower_dialog.visible and campaign.game.data.balance == balance, "Tower " + action + " shields backdrop input")
		await back()
		check(campaign.tower_dialog.visible and campaign.tower_dialog.mode == "info", "Tower " + action + " Back restores management")
	campaign.show_socket(socket.index)
	await settle()
	await press(named("Manage_target"))
	for target in Balance.TARGET_MODES:
		await press(named("Target_" + target))
		check(campaign.tower_dialog.target_choice == target and tower.get("target_mode", "first") == "first", "Target selection waits for Apply")
	await press(campaign.tower_dialog.confirm)
	check(tower.target_mode == Balance.TARGET_MODES.keys()[-1], "Touch applies targeting")
	for index in 18: Relics.award(campaign.game.data, "90,%d" % index, Relics.DEFINITIONS.keys()[index % Relics.DEFINITIONS.size()])
	campaign.show_socket(socket.index)
	await settle()
	await press(named("Manage_equipment"))
	var dialog: VigilTowerDialog = campaign.tower_dialog
	await swipe(dialog.scroll.get_global_rect().get_center(), Vector2(0, -70))
	check(dialog.scroll.scroll_vertical > 0 and dialog.mode == "equipment", "Equipment inventory swipes without selecting")
	await press(named("Relic_90,17"))
	check(dialog.mode == "equipment_detail", "Last equipment row opens by touch")
	await audit(dialog.card, "Equipment detail")
	await back()
	check(dialog.visible and dialog.mode == "equipment" and not tower.has("relic"), "Equipment detail Back retains inventory without equipping")
	await press(named("Relic_90,17"))
	await press(dialog.confirm)
	check(dialog.mode == "equipment" and tower.relic == "90,17", "Touch equips inventory item")
	await press(named("RemoveEquipment"))
	await audit(dialog.card, "Equipment removal")
	await back()
	check(dialog.visible and dialog.mode == "equipment" and tower.relic == "90,17", "Equipment removal Back cancels without removing")
	await press(named("RemoveEquipment"))
	await press(dialog.confirm)
	check(dialog.mode == "equipment" and not tower.has("relic"), "Touch confirms equipment removal")
	await back()
	campaign.show_socket(socket.index)
	await settle()
	await press(named("Manage_move"))
	await press(dialog.confirm)
	check(campaign.tower_move.visible and campaign.board.moving_tower == id, "Move touch starts destination selection")
	await press(campaign.tower_move.cancel_button)
	check(not campaign.tower_move.visible and campaign.board.moving_tower.is_empty(), "Move Cancel clears destination selection")
	campaign.show_socket(socket.index)
	await settle()
	await press(named("Manage_move"))
	await press(dialog.confirm)
	var destination: Dictionary = campaign.run.mission.sockets[1]
	campaign.board.camera = destination.position
	campaign.board.camera_framing.cancel()
	await settle()
	await tap_at(campaign.board.global_position + campaign.board.screen(destination.position))
	var location := VigilWorld.ground_location(destination.position)
	check(tower.region == location.region and tower.pad == location.pad and not campaign.tower_move.visible, "Touch relocates to clear ground using grid coordinates")
	tower.rebuild_remaining = 0.0
	campaign.select_ground_tower(tower.region, tower.pad)
	await settle()
	await press(named("Manage_sell"))
	await capture("tower-sale")
	await press(dialog.cancel)
	check(campaign.game.data.towers.has(id), "Touch sale Cancel preserves tower")
	await press(named("Manage_sell"))
	await press(dialog.confirm)
	check(not campaign.game.data.towers.has(id) and not dialog.visible, "Touch confirms sale once")

func map_gestures() -> void:
	campaign.clear_selection()
	campaign.board.set_unrestricted_camera(true)
	await settle()
	var point: Vector2 = campaign.board.get_global_rect().get_center()
	var before: Vector2 = campaign.board.camera
	await swipe(point, Vector2(60, 20))
	check(campaign.board.camera != before and campaign.board.touches.is_empty(), "Battlefield drag pans and releases")
	var zoom: float = campaign.board.zoom
	await finger(point - Vector2(30, 0), true, 0)
	await finger(point + Vector2(30, 0), true, 1)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = point + Vector2(70, 0)
	drag.relative = Vector2(40, 0)
	Input.parse_input_event(drag)
	await process_frame
	await finger(point + Vector2(70, 0), false, 1)
	await finger(point - Vector2(30, 0), false, 0)
	await settle()
	check(campaign.board.zoom > zoom and campaign.board.touches.is_empty() and not campaign.dialog.visible, "Pinch zooms without selecting a socket on release")

func result_routes() -> void:
	app.slot_menu.hide()
	campaign.start_mission(0)
	campaign.begin_wave()
	campaign.run.phase = "defeat"
	campaign.show_result()
	await audit(campaign.dialog_card, "Defeat")
	await capture("defeat")
	for button in campaign.dialog_body.find_children("*", "Button", true, false):
		if button.text == "Restart level":
			await press(button)
			break
	check(campaign.run.phase == "planning" and not campaign.dialog.visible, "Touch restarts defeated level")
	campaign.run.phase = "victory"
	campaign.run.wave = campaign.run.mission.waves.size()
	campaign.show_result()
	await audit(campaign.dialog_card, "Victory")
	await press(named("NextCampaignLevel"))
	check(campaign.run.mission.index == 1 and campaign.run.phase == "planning", "Touch advances to next level")
	campaign.begin_wave()
	campaign.run.phase = "defeat"
	campaign.show_result()
	for button in campaign.dialog_body.find_children("*", "Button", true, false):
		if button.text == "World map":
			await press(button)
			break
	check(campaign.page == "map", "Result World map touch returns to map")
	await back()
	check(app.slot_menu.visible and app.slot_menu.screen == "slots" and not is_instance_valid(app.campaign), "Map system Back follows visible Back to saved games")
