extends "res://tests/rendered/campaign_runner.gd"

func click_action(app: Control, button: Button, touch: bool) -> void:
	await Harness.tap(app, button.get_global_rect().get_center(), touch)
	await frame()

func run() -> void:
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-upgrade-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	screen.progress.data.completed_levels = 20
	for touch in [false, true]:
		for index in range(20):
			screen.start_mission(index)
			await frame()
			var socket: Dictionary = screen.run.mission.sockets[0]
			screen.run.build(socket.index, "rapid")
			screen.show_socket(socket.index)
			await frame()
			var tower: Dictionary = screen.game.data.towers[screen.run.tower_at(socket.index)]
			var upgrade: Button = screen.tower_actions.buttons.upgrade
			var context := "Level %d %s" % [index + 1, "touch" if touch else "mouse"]
			check(upgrade.mouse_filter == Control.MOUSE_FILTER_STOP, context + " retains button input boundary")
			check(screen.board.get_global_rect().encloses(upgrade.get_global_rect()), context + " upgrade button is reachable")
			var before: float = screen.game.data.balance
			var quote := Balance.upgrade_cost(tower, screen.game.tuning)
			await click_action(app, upgrade, touch)
			check(tower.level == 1 and screen.tower_actions.pending_tower == tower.id and screen.game.data.balance == before, context + " first tap only arms")
			await click_action(app, upgrade, touch)
			check(tower.level == 2 and screen.game.data.balance == before - quote, context + " second tap purchases upgrade")
			screen.begin_wave()
			screen.show_socket(socket.index)
			screen.game.data.balance = 10000.0
			await click_action(app, upgrade, touch)
			await click_action(app, upgrade, touch)
			check(tower.level == 3 and upgrade.disabled and screen.tower_actions.branch_bar.visible, context + " branches unlock at level 3")
			var branch: Button = screen.tower_actions.branch_bar.get_child(1)
			before = screen.game.data.balance
			quote = Balance.upgrade_cost(tower, screen.game.tuning, "thorn_volley")
			await click_action(app, branch, touch)
			check(tower.level == 3 and screen.tower_actions.chosen_branch == "thorn_volley", context + " branch waits for confirmation")
			await click_action(app, branch, touch)
			check(tower.level == 4 and tower.branch == "thorn_volley" and screen.game.data.balance == before - quote, context + " branch purchases once")
			check(not screen.game.economy.upgrade(tower.id) and upgrade.disabled, context + " max level stays locked")
			# The same transaction rejects insufficient gold, rebuilding and stale tiers.
			tower.level = 1
			tower.erase("branch")
			screen.game.data.balance = 0.0
			screen.tower_actions.refresh()
			check(upgrade.disabled and not screen.game.economy.upgrade(tower.id), context + " insufficient currency remains blocked")
			screen.game.data.balance = 10000.0
			tower.rebuild_remaining = 1.0
			screen.tower_actions.refresh()
			check(upgrade.disabled and not screen.game.economy.upgrade(tower.id), context + " rebuilding remains blocked")
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
