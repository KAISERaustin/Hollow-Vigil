extends "res://tests/rendered/campaign_runner.gd"

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://upgrade-cost-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	screen.progress.data.completed_levels = 6
	screen.start_mission(6)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frame()
		screen.start_mission(6)
		await frame()
		var socket: Dictionary = screen.run.mission.sockets[1]
		screen.game.data.balance = 10000.0
		screen.run.build(socket.index, "rapid")
		screen.show_socket(socket.index)
		await frame()
		var tower: Dictionary = screen.game.data.towers[screen.run.tower_at(socket.index)]
		var actions: VigilTowerActions = screen.tower_actions
		check(actions.pending_tower == "" and actions.upgrade_quote.visible and actions.upgrade_quote.text.contains(actions.UI.exact_money(Balance.upgrade_cost(tower, screen.game.tuning)) + " gold"), "Default price visible before first tap " + str(dimensions))
		check(screen.board.get_global_rect().encloses(actions.upgrade_quote.get_global_rect()), "Price fits battlefield")
		screen.game.data.settings.developer_balance = {"towers": {"rapid:2": {"cost": 123.0}, "rapid:frostneedle": {"cost": 345.0}, "rapid:thorn_volley": {"cost": 456.0}}}
		actions.refresh()
		check(actions.upgrade_quote.text.contains("123 gold"), "Price reacts to campaign tier override")
		actions.request_upgrade()
		screen.game.data.settings.developer_balance.towers["rapid:2"].cost = 124.0
		actions.refresh()
		check(actions.pending_tower == "" and actions.upgrade_quote.text.contains("124 gold"), "Changed price cancels old confirmation and shows new quote")
		screen.game.data.balance = 123.0
		actions.refresh()
		check(actions.buttons.upgrade.disabled and actions.upgrade_quote.visible, "Unaffordable upgrade keeps visible price and disabled styling")
		screen.game.data.balance = 10000.0
		actions.request_upgrade()
		actions.request_upgrade()
		check(tower.level == 2 and screen.game.data.balance == 9876.0, "Displayed tier price equals charged amount")
		screen.game.economy.upgrade(tower.id)
		actions.refresh()
		await frame()
		check(actions.upgrade_quote.text.contains("345 gold") and actions.upgrade_quote.text.contains("456 gold") and actions.upgrade_quote.text.contains("Poison Arrow"), "Both specialization prices and current names are visible")
		check(screen.board.get_global_rect().encloses(actions.upgrade_quote.get_global_rect()), "Both specialization quotes fit viewport")
		await Harness.capture(app, "campaign-upgrade-prices-" + str(dimensions.x))
		actions.choose_branch(1)
		var before: float = screen.game.data.balance
		actions.choose_branch(1)
		check(tower.level == 4 and screen.game.data.balance == before - 456.0, "Displayed branch price equals charged amount")
		check(not actions.upgrade_quote.visible and actions.buttons.upgrade.disabled, "Max level does not advertise another purchase")
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
	print("UPGRADE COST UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
