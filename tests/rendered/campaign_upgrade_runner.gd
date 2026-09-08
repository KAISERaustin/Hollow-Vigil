extends "res://tests/rendered/campaign_runner.gd"

func click_action(app: Control, button: Button, touch: bool) -> void:
	await Harness.tap(app, button.get_global_rect().get_center(), touch)
	await frame()

func run() -> void:
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-upgrade-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	screen.progress.data.completed_levels = preload("res://scripts/campaign/catalog.gd").COUNT
	for touch in [false, true]:
		for index in range(preload("res://scripts/campaign/catalog.gd").COUNT):
			screen.start_mission(index)
			await frame()
			var socket: Dictionary = screen.run.mission.sockets[0]
			screen.run.build(socket.index, "rapid")
			screen.show_socket(socket.index)
			check(screen.tower_dialog.visible and screen.tower_dialog.mode == "info" and not screen.tower_actions.visible, "Tower selection opens shared management")
			check(not screen.tower_actions.upgrade_quote.visible, "Tower selection omits the bottom upgrade notification")
			await frame()
			var tower: Dictionary = screen.game.data.towers[screen.run.tower_at(socket.index)]
			var upgrade: Button = screen.tower_dialog.confirm
			var context := "Level %d %s" % [index + 1, "touch" if touch else "mouse"]
			check(upgrade.mouse_filter != Control.MOUSE_FILTER_IGNORE, context + " retains button input boundary")
			check(screen.board.get_global_rect().encloses(upgrade.get_global_rect()), context + " upgrade button is reachable")
			var before: float = screen.game.data.balance
			var quote := Balance.upgrade_cost(tower, screen.game.tuning)
			await click_action(app, upgrade, touch)
			check(tower.level == 1 and screen.tower_dialog.visible and screen.tower_dialog.mode == "info" and screen.tower_dialog.upgrade_armed and screen.game.data.balance == before, context + " upgrade button opens comparison without spending")
			check(not screen.tower_actions.visible and screen.tower_actions.pending_tower.is_empty(), context + " preview hides surrounding buttons without a checkmark")
			check(screen.tower_dialog.cost == quote, context + " confirmation shows the exact cost")
			screen.tower_dialog.go_back()
			await frame()
			check(screen.tower_dialog.visible and not screen.tower_dialog.upgrade_armed and tower.level == 1 and screen.game.data.balance == before, context + " close restores controls without purchasing")
			await click_action(app, upgrade, touch)
			var old_revision: int = screen.tower_dialog.revision
			await click_action(app, screen.tower_dialog.confirm, touch)
			check(tower.level == 2 and screen.game.data.balance == before - quote, context + " panel action purchases upgrade")
			screen.tower_dialog.commit(old_revision)
			check(tower.level == 2 and screen.game.data.balance == before - quote, context + " duplicate confirmation cannot purchase twice")
			check(screen.tower_dialog.visible and screen.tower_dialog.mode == "info" and not screen.tower_dialog.upgrade_armed, context + " purchase returns to unarmed management")
			screen.begin_wave()
			screen.show_socket(socket.index)
			screen.game.data.balance = 10000.0
			await click_action(app, upgrade, touch)
			var wave_time: float = screen.run.wave_time
			screen._process(0.1)
			check(not screen.paused and screen.run.wave_time > wave_time and screen.tower_dialog.visible, context + " upgrade comparison keeps campaign running")
			await click_action(app, screen.tower_dialog.confirm, touch)
			screen.show_socket(socket.index)
			check(tower.level == 3 and screen.tower_dialog.branch_cards.visible, context + " level 3 keeps a single upgrade entry point")
			await click_action(app, upgrade, touch)
			var branch: Button = screen.tower_dialog.find_child("Branch_thorn_volley", true, false)
			before = screen.game.data.balance
			quote = Balance.upgrade_cost(tower, screen.game.tuning, "thorn_volley")
			await click_action(app, branch, touch)
			check(tower.level == 3 and screen.tower_dialog.tower_branch == "thorn_volley" and screen.game.data.balance == before, context + " branch only updates the comparison")
			await click_action(app, screen.tower_dialog.confirm, touch)
			check(tower.level == 4 and tower.branch == "thorn_volley" and screen.game.data.balance == before - quote, context + " branch purchases once")
			screen.show_socket(socket.index)
			check(not screen.game.economy.upgrade(tower.id) and upgrade.disabled, context + " max level stays locked")
			# The same transaction rejects insufficient gold, rebuilding and stale tiers.
			tower.level = 1
			tower.erase("branch")
			screen.game.data.balance = 0.0
			screen.tower_dialog.open_action("info")
			await frame()
			await click_action(app, upgrade, touch)
			check(screen.tower_dialog.visible and screen.tower_dialog.confirm.disabled and not screen.game.economy.upgrade(tower.id), context + " insufficient currency blocks purchase while keeping comparison readable")
			screen.game.data.balance = 10000.0
			tower.rebuild_remaining = 1.0
			screen.tower_dialog.refresh()
			check(screen.tower_dialog.confirm.disabled and screen.tower_dialog.rebuild_status.visible and not screen.game.economy.upgrade(tower.id), context + " rebuilding remains blocked")
			screen.tower_dialog.dismiss()
			tower.rebuild_remaining = 0.0
			check(not screen.game.economy.upgrade(tower.id, 2) and not screen.game.economy.upgrade(tower.id, 1, "thorn_volley"), context + " stale tier and unmet branch prerequisite remain blocked")
			tower.level = 3
			check(not screen.game.economy.upgrade(tower.id, 3) and not screen.game.economy.upgrade(tower.id, 3, "invalid"), context + " specialization must be valid")
	var prefix: String = app.game.save_path.get_file()
	screen.close()
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(prefix): DirAccess.remove_absolute("user://" + filename)
	app.audio.set_suspended(true)
	app.audio.music.stop()
	app.audio.music.stream = null
	for pool in app.audio.voices.values():
		for voice in pool:
			voice.stop()
			voice.stream = null
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	print("CAMPAIGN UPGRADES UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

