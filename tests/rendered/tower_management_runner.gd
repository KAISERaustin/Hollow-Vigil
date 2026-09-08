extends "res://tests/rendered/campaign_runner.gd"

func settle() -> void:
	for tick in 12: await process_frame

func exercise(host: Control, select: Callable, prefix: String) -> void:
	for viewport in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		select.call()
		await settle()
		var dialog: VigilTowerDialog = host.tower_dialog
		check(dialog.visible and dialog.mode == "info", prefix + " selection opens management")
		check(not host.tower_actions.visible, "No surrounding controls")
		check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(dialog.card.get_global_rect()), "Management fits portrait")
		check(dialog.confirm.is_visible_in_tree(), "Upgrade stays visible")
		await Harness.capture(host, "tower-management-" + prefix + "-" + str(viewport.x))
		for action in ["equipment", "target", "move", "sell"]:
			dialog.body.find_child("Manage_" + action, true, false).pressed.emit()
			await settle()
			check(dialog.mode == action, "Management opens " + action)
			dialog.go_back()
			await settle()
			check(dialog.mode == "info", "Back returns to management")
		var level: int = host.game.data.towers[host.field.selected_tower].level
		dialog.confirm.pressed.emit()
		await settle()
		check(dialog.mode == "preview", "Upgrade opens comparison")
		check(host.game.data.towers[host.field.selected_tower].level == level, "Preview does not purchase")
		dialog.go_back()
		await settle()
		dialog.go_back()
		check(not dialog.visible, "Back closes management")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://tower-management-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.field.set_process(false)
	app.game.data.balance = 100000
	app.game.expand("1,0")
	app.game.economy.build("rapid", "0,0", 1)
	await settle()
	await exercise(app, func(): app.panels.select_pad("0,0", 1), "infinite")
	app.panels.close_sheet()
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.start_mission(0)
	campaign.field.set_process(false)
	campaign.game.data.balance = 100000
	var socket: int = campaign.run.mission.sockets[1].index
	campaign.run.build(socket, "rapid")
	await exercise(campaign, func(): campaign.show_socket(socket), "campaign")
	app.free()
	print("TOWER MANAGEMENT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
