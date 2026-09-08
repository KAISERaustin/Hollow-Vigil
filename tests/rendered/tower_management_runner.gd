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
		check(dialog.card.size.y <= 240, "Management remains a compact card")
		check(dialog.body.find_child("TowerDetails", true, false) == null, "Compact card omits stats and description")
		var action_y := dialog.confirm.get_global_rect().position.y
		for button: Button in dialog.footer.get_children():
			if not button.visible: continue
			check(button.size == Vector2(48, 48) and is_equal_approx(button.global_position.y, action_y), "Five square actions share one row")
			check(button.text.is_empty() and not button.accessibility_name.is_empty(), "Icon actions retain accessible names")
		check(absf(dialog.portrait.get_global_rect().get_center().y - dialog.identity_text.get_global_rect().get_center().y) < 1, "Portrait and title vertically centered in identity card")
		check(dialog.identity_card.get_theme_stylebox("panel").border_width_left == 3, "Identity card uses shared black outline")
		await Harness.capture(host, "tower-management-" + prefix + "-" + str(viewport.x))
		for action in ["equipment", "target", "move", "sell"]:
			dialog.find_child("Manage_" + action, true, false).pressed.emit()
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
