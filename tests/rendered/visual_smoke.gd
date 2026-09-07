extends RefCounted

static func tap(app: Control, position: Vector2, touch: bool = false) -> void:
	if touch:
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = position
		press.pressed = true
		Input.parse_input_event(press)
		await app.get_tree().process_frame
		var release := press.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
	else:
		var motion := InputEventMouseMotion.new()
		motion.position = position
		Input.parse_input_event(motion)
		await app.get_tree().process_frame
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = position
		press.pressed = true
		Input.parse_input_event(press)
		await app.get_tree().process_frame
		var release := press.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	# Selecting or reopening a tower can frame it over 0.4 seconds. The next
	# action must target its settled position, as a player sees it.
	for frame in 60:
		if not app.field.camera_framing.active: break
		await app.get_tree().process_frame

static func capture(app: Control, filename: String) -> void:
	# Some fixtures pause the game loop before changing the camera directly.
	app.field.queue_redraw()
	await settle(app)
	await RenderingServer.frame_post_draw
	app.get_viewport().get_texture().get_image().save_png("res://artifacts/" + filename + ".png")

static func settle(app: Control) -> void:
	for frame in 4: await app.get_tree().process_frame
	for frame in 60:
		if not app.field.camera_framing.active: break
		await app.get_tree().process_frame

static func run(app: Control) -> void:
	var game: VigilState = app.game
	var failures: Array[String] = []
	await app.get_tree().create_timer(0.25).timeout
	await capture(app, "new-game-core-only")
	if not game.data.towers.is_empty():
		failures.append("New game already has a tower")
	if not game.combat.enemies.is_empty():
		failures.append("New game spawned enemies before territory purchase")
	app.panels.select_pad("0,0", 0)
	app.update_hud()
	if not app.panels.action_button.disabled:
		failures.append("Tower build button is enabled before the first property purchase")
	await capture(app, "first-property-required")
	app.panels.action_button.pressed.emit()
	if not game.data.towers.is_empty() or game.data.balance != Balance.STARTING_GOLD:
		failures.append("Build callback bypassed the first property requirement")
	app.panels.close_sheet()
	app.field.camera = Vector2(-150, 0)
	await tap(app, app.field.global_position + app.field.screen(app.field.expansion_marker("-1,0")))
	await tap(app, app.panels.action_button.global_position + app.panels.action_button.size * 0.5)
	if not game.data.regions.has("-1,0") or game.data.balance != Balance.STARTING_GOLD - Balance.expansion_cost(1):
		failures.append("Starting gold did not fund the first territory through the purchase UI")
	app.field.camera = Vector2.ZERO
	app.panels.select_pad("0,0", 0)
	await capture(app, "first-tower-purchase")
	await tap(app, app.panels.action_button.get_global_rect().get_center())
	if game.data.towers.size() != 1 or game.data.balance != Balance.STARTING_GOLD - Balance.expansion_cost(1) - Balance.TOWERS.rapid.cost:
		failures.append("First tower purchase did not charge its price")
	if "--first-property-only" in OS.get_cmdline_user_args():
		for failure in failures:
			push_error(failure)
		print("FIRST_PROPERTY_UI: %d failures" % failures.size())
		app.get_tree().quit(0 if failures.is_empty() else 1)
		return
	app.panels.close_sheet()
	game.data.balance = 900.0
	game.economy.build("splash", "0,0", 2)
	game.economy.build("heavy", "0,0", 1)
	game.economy.unlock("-1,0", "fast")
	game.economy.unlock("-1,0", "heavy")
	game.economy.buy_traffic("-1,0")
	for i in range(500):
		game.combat.tick(Balance.STEP)
	app.update_hud()
	app.toast_timer = 0
	await capture(app, "battlefield")
	await preload("res://tests/rendered/developer_controls_checks.gd").run(app, load("res://tests/rendered/visual_smoke.gd"), failures)
	await preload("res://tests/rendered/tower_panel_checks.gd").run(app, load("res://tests/rendered/visual_smoke.gd"), failures)
	await preload("res://tests/rendered/relocation_ui_checks.gd").run(app, load("res://tests/rendered/visual_smoke.gd"), failures)
	# Exercise the neighboring map controls through real mouse and touch events.
	var frontier_id := ""
	for candidate in VigilWorld.frontier(game.data.regions, int(game.data.seed)):
		if Vector2(VigilWorld.coord(candidate) - Vector2i(-1,0)).length() == 1.0:
			frontier_id = candidate
			break
	for scale in [1.0, 0.65, 0.42, 1.65]:
		app.field.zoom = scale
		var portal: Vector2 = game.paths["-1,0"][0]
		var frontier: Vector2 = app.field.expansion_marker(frontier_id)
		app.field.camera = (portal + frontier) * 0.5
		for touch in [false, true]:
			await tap(app, app.field.global_position + app.field.screen(portal), touch)
			if app.panels.mode != "rift" or not app.panels.visible:
				failures.append("Rift did not open its upgrades at zoom %.2f (touch=%s)" % [scale, touch])
			app.panels.close_sheet()
			await tap(app, app.field.global_position + app.field.screen(frontier), touch)
			if app.panels.mode != "expand" or not app.panels.visible:
				failures.append("Expansion opened the wrong panel at zoom %.2f (touch=%s)" % [scale, touch])
			app.panels.close_sheet()
		var gate_screen: Vector2 = app.field.screen(portal)
		var expand_screen: Vector2 = app.field.screen(frontier)
		var outward := gate_screen.direction_to(expand_screen)
		var gap: Vector2 = (gate_screen + outward * app.field.entrance_hit_radius() + expand_screen - outward * Battlefield.EXPANSION_HIT_RADIUS * app.field.zoom) * 0.5
		await tap(app, app.field.global_position + gap)
		if app.panels.visible:
			failures.append("Space between rift and expansion opened a panel at zoom %.2f" % scale)
		await capture(app, "portal-spacing-%.2f" % scale)
	app.field.camera = Vector2.ZERO
	app.field.zoom = 1.0
	await tap(app, app.field.global_position + app.field.screen(VigilWorld.CORE_POSITION), true)
	if app.panels.mode != "core":
		failures.append("Physical touch on the central portal did not show core details")
	await capture(app, "core-info")
	app.panels.close_sheet()
	await tap(app, app.field.global_position + app.field.screen(VigilWorld.CORE_POSITION))
	if app.panels.mode != "core":
		failures.append("Mouse click on the core artwork did not show core details")
	app.panels.close_sheet()
	app.panels.select_pad("0,0", 0)
	await tap(app, app.tower_actions.buttons.upgrade.get_global_rect().get_center(), true)
	await capture(app, "upgrade")
	var earned := game.economy.unclaimed()
	var before: float = game.data.balance
	# Collect through the HUD before confirming the inline upgrade.
	app.tower_actions.cancel_upgrade()
	await tap(app, app.hud.collect_button.global_position + app.hud.collect_button.size * 0.5, true)
	if game.data.balance < before + earned:
		failures.append("Physical touch did not collect through the live HUD")
	var level: int = game.data.towers["1"].level
	await tap(app, app.tower_actions.buttons.upgrade.get_global_rect().get_center(), true)
	await tap(app, app.tower_actions.buttons.upgrade.get_global_rect().get_center(), true)
	if game.data.towers["1"].level != level + 1:
		failures.append("Physical touch did not buy upgrade while collection animated")
	app.panels.select_pad("0,0", 3)
	await capture(app, "build")
	await tap(app, app.panels.action_button.global_position + app.panels.action_button.size * 0.5)
	if game.economy.tower_at("0,0", 3) == "":
		failures.append("Live build confirmation did not place a tower")
	app.panels.show_entrance("-1,0")
	await capture(app, "rift")
	game.data.balance = 500.0
	app.panels.show_expansion("0,-1")
	await capture(app, "expansion")
	await tap(app, app.panels.action_button.global_position + app.panels.action_button.size * 0.5)
	if not game.data.regions.has("0,-1"):
		failures.append("Live expansion confirmation failed")
	app.panels.show_settings()
	await capture(app, "settings")
	if app.panels.position.y < 140:
		failures.append("Settings panel overflows the header")
	app.panels.close_sheet()
	game.economy.build("rapid", "0,-1", 2)
	game.economy.build("heavy", "0,-1", 3)
	app.field.camera = Vector2(0, -150)
	app.field.zoom = 0.83
	for i in range(260):
		game.combat.tick(Balance.STEP)
	app.update_hud()
	app.toast_timer = 0
	await capture(app, "expanded-battlefield")
	game.data.balance = 100000.0
	for id in ["-1,0", "1,0", "0,1"]:
		game.expand(id)
		game.economy.build("rapid", id, 0)
	app.field.camera = VigilWorld.CORE_POSITION
	app.field.zoom = 0.5
	for i in range(240):
		game.combat.tick(Balance.STEP)
	app.update_hud()
	await capture(app, "core-surrounded")
	for path in game.paths.values():
		if path.back() != Vector2.ZERO:
			failures.append("An expanded territory does not lead to the central core")
	app.field.camera = Vector2(300, 300)
	app.panels.return_to_core()
	if app.field.camera != Vector2.ZERO or app.field.zoom != 1.0 or app.panels.visible:
		failures.append("Return to core did not restore the central view")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	if not game.suspended:
		failures.append("Lifecycle pause did not suspend live simulation")
	game.data.last_accounted -= 60.0
	var offline_before := game.economy.unclaimed()
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	if game.suspended or game.economy.unclaimed() <= offline_before:
		failures.append("Lifecycle resume did not apply demonstrated offline earnings")
	var accounted := game.economy.unclaimed()
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	if game.economy.unclaimed() != accounted:
		failures.append("Duplicate resume applied the same offline interval twice")
	await capture(app, "return-earnings")
	if not app.return_overlay.visible:
		failures.append("Resume earnings did not open the return popup")
	var balance_before_popup: float = game.data.balance
	await tap(app, app.hud.collect_button.get_global_rect().get_center())
	await tap(app, Vector2(8, 300), true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	var escape_release := escape.duplicate()
	escape_release.pressed = false
	Input.parse_input_event(escape_release)
	await app.get_tree().process_frame
	if app.return_overlay.visible:
		failures.append("Escape did not close return earnings")
	app.show_return_earnings(376)
	for i in range(40):
		app._process(0.25)
	app.toast_timer = 0.0
	if not app.return_overlay.visible:
		failures.append("Return popup dismissed without user action")
	if game.data.balance != balance_before_popup:
		failures.append("Return popup allowed collection through the backdrop")
	if app.return_card.get_global_rect().get_center().distance_to(app.size * 0.5) > 1.0:
		failures.append("Return popup is not centered")
	await tap(app, app.return_close.get_global_rect().get_center(), true)
	if app.return_overlay.visible:
		failures.append("Touch Close did not dismiss the return popup")
	app.show_return_earnings(376)
	var original_size := app.get_window().size
	var original_scale := app.get_window().content_scale_size
	app.get_window().content_scale_size = Vector2i(420, 800)
	app.get_window().size = Vector2i(420, 800)
	await capture(app, "return-earnings-compact")
	await tap(app, app.return_close.get_global_rect().get_center())
	if app.return_overlay.visible:
		failures.append("Mouse Close did not dismiss the compact return popup")
	app.get_window().content_scale_size = original_scale
	app.get_window().size = original_size
	await test_camera_independent_combat(app, failures)
	app.set_process(false)
	app.panels.show_settings()
	await capture(app, "reset-settings")
	var children: Array = app.panels.sheet_content.get_children()
	var reset_button: Button = children[-2].get_child(1)
	if children[-2].get_child(0).text != "Reset progress":
		failures.append("Recovery-compatible legacy reset action is missing")
	var before_reset: Dictionary = app.game.data.duplicate(true)
	app.panels.content_scroll.ensure_control_visible(reset_button)
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	await tap(app, reset_button.get_global_rect().get_center())
	await capture(app, "reset-confirmation")
	await tap(app, app.panels.action_footer.get_children()[0].get_global_rect().get_center())
	if app.game.data != before_reset:
		failures.append("Cancel reset changed progress")
	var reset_again: Button = app.panels.sheet_content.get_children()[-2].get_child(1)
	app.panels.content_scroll.ensure_control_visible(reset_again)
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	await tap(app, reset_again.get_global_rect().get_center())
	await tap(app, app.panels.action_footer.get_children()[-1].get_global_rect().get_center(), true)
	if app.game.data.regions.size() != 1 or not app.game.data.towers.is_empty() or app.game.data.balance != Balance.STARTING_GOLD or app.panels.visible:
		failures.append("Confirmed reset did not restore starting progress and dismiss settings")
	if app.field.camera != Vector2.ZERO or app.field.zoom != 1.0 or app.field.state != app.game:
		failures.append("Reset did not restore the live battlefield")
	await capture(app, "reset-complete")
	var f := FileAccess.open("res://artifacts/visual-results.txt", FileAccess.WRITE)
	f.store_string("Rendered Godot smoke test\nMouse and touch rift/expansion selection at four zoom levels, neutral gap between controls, touch and mouse core details, central routes from all four directions, return to core, touch collection, touch upgrades, purchases during animations, build confirmation, expansion confirmation, panel bounds, lifecycle pause/resume, duplicate resume protection.\nFailures: %d\n" % failures.size())
	for failure in failures:
		f.store_line(failure)
		push_error(failure)
	f.store_line("Tower controls: map-anchored Info/Upgrade/Sell icons and earnings badges that scale with their towers, no selection camera movement, stable HUD, centered confirmations, mouse/touch actions at four zooms and three viewport sizes, collection, cancel, upgrade, sale and persistence.")
	f.store_line("Map cleanup: no core/rift labels or tower level dots; all gold badges and their click targets hide during tower management and restore on click-away or another panel.")
	f.store_line("World simulation: 33 territories, repeated camera moves and zooms, return to core, distant upgrades/unlocks, identical enemies and per-tower income against a stationary reference.")
	f.close()
	print("VISUAL_SMOKE: %d failures" % failures.size())
	app.get_tree().quit(0 if failures.is_empty() else 1)

static func camera_test_world() -> VigilState:
	var g := VigilState.new(569)
	g.data.first_property_required = false # Retain the legacy 33-road camera fixture.
	g.data.towers.clear()
	g.save_path = "user://smoke.save"
	g.combat.rng.seed = 569
	g.data.balance = 1.0e12
	for side in [-1, 1]:
		for i in range(1, 17):
			var id := "%d,0" % (side * i)
			g.data.regions[id] = VigilWorld.make_region(id, "%d,0" % (side * (i-1)), int(g.data.seed))
			g.refresh_paths()
			g.economy.build("rapid", id, 1 if side < 0 else 0)
	return g

static func test_camera_independent_combat(app: Control, failures: Array[String]) -> void:
	app.set_process(false)
	var original: VigilState = app.game
	var moving := camera_test_world()
	var stationary := camera_test_world()
	app.game = moving
	app.field.state = moving
	app.panels.close_sheet()
	app.accumulator = 0.0
	# Keep this controlled comparison out of the automatic save interval.
	app.save_timer = -1000.0
	for i in range(240):
		if i % 20 == 0:
			app.field.camera = Vector2(-4800 if i % 40 == 0 else 4800, 0)
			app.field.camera_changed.emit()
			app.field.set_zoom(0.42 if i % 40 == 0 else 1.65, app.field.size * 0.5)
		if i % 60 == 30:
			app.panels.return_to_core()
		if i == 120:
			for g in [moving, stationary]:
				g.economy.buy_traffic("-16,0")
				g.economy.unlock("-16,0", "fast")
				g.economy.unlock("-16,0", "heavy")
				g.economy.upgrade(g.economy.tower_at("-16,0", 1))
		var ticks_before: int = moving.combat.tick_count
		app._process(0.25)
		for tick in range(moving.combat.tick_count - ticks_before):
			stationary.combat.tick(Balance.STEP)
		if i % 20 == 0:
			await app.get_tree().process_frame
	if moving.combat.enemy_serial != stationary.combat.enemy_serial or moving.combat.enemies != stationary.combat.enemies:
		failures.append("Moving the camera changed spawning or live enemy state")
	if moving.data.towers != stationary.data.towers or moving.data.regions != stationary.data.regions:
		failures.append("Moving the camera changed tower income, cooldowns, or rift production")
	if moving.data.kills != stationary.data.kills or moving.data.escapes != stationary.data.escapes or moving.combat.income_rate() != stationary.combat.income_rate():
		failures.append("Moving the camera changed actual kills, escapes, or gold per second")
	# The generated corridor includes quiet castle tiles and sockets away from
	# traffic. Every tower's exact earnings were compared above; positive controls
	# at both distant ends demonstrate that off-camera production actually ran.
	for side in [-1, 1]:
		var distant: String = moving.economy.tower_at("%d,0" % (side * 16), 1 if side < 0 else 0)
		if moving.data.towers[distant].earnings <= 0.0:
			failures.append("Distant tower %s earned nothing while the camera was elsewhere" % distant)
	for side in [-1, 1]:
		app.field.camera = Vector2(side * 4800, 0)
		app.field.zoom = 0.83
		app.field.queue_redraw()
		app.update_hud()
		await capture(app, "all-territories-west" if side < 0 else "all-territories-east")
	print("CAMERA_SIMULATION: %d territories, %d spawns, %d kills; per-tower income and live enemies compared with stationary reference" % [moving.data.regions.size(), moving.combat.enemy_serial, moving.data.kills])
	app.game = original
	app.field.state = original
	app.panels.return_to_core()
	app.save_timer = 0.0
	app.accumulator = 0.0
	app.set_process(true)
