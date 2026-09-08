extends SceneTree
## Supplement full menu navigation with contextual transactions and return earnings.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Touch = preload("res://tests/rendered/visual_smoke.gd")
var app: VigilApp
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	preload("res://tests/support/timeout.gd").arm(self, 240)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	await Touch.settle(app)

func press(button: BaseButton) -> void:
	check(is_instance_valid(button), "Context action exists")
	if not is_instance_valid(button): return
	var owner := button.get_parent()
	while owner != null:
		if owner is ScrollContainer: owner.ensure_control_visible(button)
		owner = owner.get_parent()
	await settle()
	check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(button.get_global_rect()), "Context action fits: " + button.name)
	check(button.size.x >= UI.TARGET and button.size.y >= UI.TARGET, "Context action has a full touch target: " + button.name)
	await Touch.tap(app, button.get_global_rect().get_center(), true)
	await settle()

func back() -> void:
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()

func open_world(point: Vector2) -> void:
	app.field.camera_framing.cancel()
	app.field.camera = point
	app.field.zoom = 1.0
	await settle()
	await Touch.tap(app, app.field.global_position + app.field.screen(point), true)
	await settle()

func close_sheet() -> void:
	await press(app.panels.find_child("CloseSheet", true, false))
	check(not app.panels.visible, "Touch closes contextual sheet")

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/mobile-context-%s-%dx%d.png" % [label, root.size.x, root.size.y])

func run() -> void:
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app = VigilApp.new()
		app.load_saved_progress = false
		app.game.save_path = "user://mobile-context-" + str(Time.get_ticks_usec()) + ".save"
		root.add_child(app)
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.set_process(false)
		app.audio.set_suspended(true)
		app.field.set_unrestricted_camera(true)
		Engine.max_fps = 240
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		await settle()
		await world_actions()
		await return_earnings()
		await reset_actions()
		var prefix := app.game.save_path.get_file()
		app.queue_free()
		await process_frame
		await process_frame
		for filename in DirAccess.get_files_at("user://"):
			if filename.begins_with(prefix): DirAccess.remove_absolute("user://" + filename)
	print("MOBILE CONTEXT ACTIONS: %d checks, %d failures; return earnings, collection, core, territory, portal and reset at three portrait sizes" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func world_actions() -> void:
	await open_world(VigilWorld.CORE_POSITION)
	check(app.panels.visible and app.panels.mode == "core", "Touch opens Core information")
	await close_sheet()
	app.game.data.balance = 1000000
	var region := "-1,0"
	var marker := app.field.expansion_marker(region)
	await open_world(marker)
	check(app.panels.visible and app.panels.mode == "expand", "Touch opens territory claim")
	var before: float = app.game.data.balance
	await close_sheet()
	check(not app.game.data.regions.has(region) and app.game.data.balance == before, "Closing claim preserves gold and ownership")
	await open_world(marker)
	var cost: float = app.panels.action_cost
	await press(app.panels.action_button)
	check(app.game.data.regions.has(region) and app.game.data.balance == before - cost and not app.panels.visible, "Touch claims territory once at the quoted price")
	var gate: Vector2 = app.game.paths[region][0]
	await open_world(gate)
	check(app.panels.visible and app.panels.mode == "rift", "Touch opens portal upgrades")
	var state: Dictionary = app.game.data.regions[region]
	var level := int(state.traffic)
	before = app.game.data.balance
	cost = app.game.economy.traffic_cost(region)
	await press(app.panels.find_child("PortalTraffic", true, false))
	check(state.traffic == level + 1 and app.game.data.balance == before - cost, "Touch buys portal spawn rate exactly once")
	for kind in Balance.portal_unlock_costs(state.style):
		before = app.game.data.balance
		cost = Balance.portal_unlock_costs(state.style)[kind]
		await press(app.panels.find_child("Attune_" + kind, true, false))
		check(kind in state.unlocks and app.game.data.balance == before - cost, "Touch attunes portal spawn " + kind)
		check(app.panels.find_child("Attune_" + kind, true, false).disabled, "Purchased attunement cannot charge again")
	before = app.game.data.balance
	app.game.data.balance = 0.0
	app.update_hud()
	var traffic: Button = app.panels.find_child("PortalTraffic", true, false)
	check(traffic.disabled, "Unaffordable portal action is disabled")
	await press(traffic)
	check(state.traffic == level + 1 and app.game.data.balance == 0.0, "Touch cannot purchase an unaffordable portal action")
	app.game.data.balance = before
	await back()
	check(not app.panels.visible, "Android Back closes portal upgrades")

func return_earnings() -> void:
	var tower_id: String = app.game.economy.build("rapid", "0,0", 0)
	check(not tower_id.is_empty(), "Return earnings fixture places a tower")
	if tower_id.is_empty(): return
	app.game.data.towers[tower_id].earnings = 400.0
	app.update_hud()
	var before: float = app.game.data.balance
	app.field.mouse_down = true
	app.field.touches[0] = Vector2(50, 50)
	app.show_return_earnings(376)
	app.show_return_earnings(24)
	await settle()
	check(app.return_overlay.visible and app.pending_return_gold == 400, "Return overlay aggregates earned gold")
	check(app.field.touches.is_empty() and not app.field.mouse_down, "Return overlay clears an interrupted world gesture")
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(app.return_card.get_global_rect()), "Return card fits the portrait viewport")
	await Touch.tap(app, app.hud.collect_button.get_global_rect().get_center(), true)
	await Touch.tap(app, Vector2(4, app.field.global_position.y + 4), true)
	check(app.return_overlay.visible and app.game.data.balance == before and app.game.economy.unclaimed() == 400, "Return backdrop blocks collection and world input")
	await capture("return-earnings")
	await back()
	check(not app.return_overlay.visible and app.pending_return_gold == 0 and app.game.economy.unclaimed() == 400, "Android Back closes return overlay without collecting")
	app.show_return_earnings(400)
	await press(app.return_close)
	check(not app.return_overlay.visible and app.game.data.balance == before, "Touch Close dismisses return overlay without changing gold")
	await press(app.hud.collect_button)
	check(app.game.data.balance == before + 400 and app.game.economy.unclaimed() == 0, "Touch collects return earnings exactly once after closing")
	await press(app.hud.collect_button)
	check(app.game.data.balance == before + 400, "Repeated collection cannot duplicate return earnings")
	var saved: Dictionary = app.game.storage.read_candidate(app.game.save_path)
	check(saved.get("balance", -1) == app.game.data.balance, "Collected earnings persist to the isolated save")

func reset_actions() -> void:
	var before: Dictionary = app.game.data.duplicate(true)
	app.panels.show_reset_confirmation()
	await settle()
	await Touch.tap(app, app.hud.collect_button.get_global_rect().get_center(), true)
	await Touch.tap(app, Vector2(4, app.field.global_position.y + 4), true)
	check(app.panels.mode == "reset" and app.panels.visible and app.game.data == before, "Reset scrim blocks underlying game actions")
	await capture("reset")
	await press(app.panels.action_footer.get_child(0))
	check(app.panels.mode == "settings" and app.game.data == before, "Touch reset Cancel preserves all progress")
	app.panels.show_reset_confirmation()
	await back()
	check(app.panels.mode == "settings" and app.game.data == before, "Android Back cancels reset without changing progress")
	app.panels.show_reset_confirmation()
	await press(app.panels.action_footer.get_child(1))
	check(not app.panels.visible and not app.reset_scrim.visible, "Confirmed reset dismisses its overlay")
	check(app.game.data.regions.size() == 1 and app.game.data.towers.is_empty() and app.game.data.balance == Balance.STARTING_GOLD, "Touch reset restores initial territory, towers and gold")
	check(app.field.camera == Vector2.ZERO and app.field.touches.is_empty(), "Reset clears touch state and restores core view")
