extends "res://tests/rendered/campaign_runner.gd"

const Choice = preload("res://scripts/ui/towers/tower_choice.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 300.0)
	call_deferred("run")

func settle() -> void:
	for tick in 10: await process_frame

func select_preview(host: Control, select: Callable) -> void:
	select.call()
	if host.tower_actions.upgrade_in_dialog:
		check(not host.tower_dialog.visible and host.tower_actions.visible, "Campaign selection exposes controls without opening upgrade details")
		if host.game.data.towers[host.field.selected_tower].level == Balance.MAX_TOWER_LEVEL:
			check(host.tower_actions.buttons.upgrade.disabled, "Campaign maximum tier locks the upgrade control")
			host.tower_dialog.open_action("preview")
		else:
			host.tower_actions.buttons.upgrade.pressed.emit()

func verify_preview(host: Control, tower: Dictionary, context: String) -> void:
	var dialog: VigilTowerDialog = host.tower_dialog
	check(dialog.visible and dialog.mode == "preview", context + " opens upgrade details directly")
	check(dialog.find_child("TowerCards", true, false) == null, context + " skips the construction catalog")
	var details: Control = dialog.body.get_node("TowerDetails")
	var next_level := mini(int(tower.level) + 1, Balance.MAX_TOWER_LEVEL)
	check(dialog.body.find_child("TowerLevelIndicator", true, false).get_meta("level") == tower.level, context + " indicator shows owned level, not preview level")
	check((dialog.body.find_child("UpgradeBranches", true, false) != null) == (tower.level == 3), context + " branches appear only at level three")
	var after := Balance.stats(tower.kind, next_level, host.game.tuning, dialog.tower_branch)
	var before := Balance.tower_stats(tower, host.game.tuning)
	var level_label := "Level %d" % next_level if tower.level == Balance.MAX_TOWER_LEVEL else "Level %d → %d" % [tower.level, next_level]
	check(details.get_node("TowerStats") != null and details.find_child("TowerLevel", true, false).text == level_label, context + " uses the build details at the next level")
	check(details.find_child("TowerDescription", true, false).text == Balance.tower_description(after), context + " describes the previewed tier")
	check(dialog.heading.text == after.name, context + " names the previewed tower")
	var grid := details.get_node("TowerStats") as GridContainer
	check(grid.find_child("Stat_period", true, false) != null and details.find_children("Stat_period", "Label", true, false).size() == 1, context + " shows the interval once inside the grid")
	for cell: PanelContainer in grid.get_children():
		check(cell.get_theme_stylebox("panel").border_width_left == UI.OUTLINE, context + " uses the shared stat card border")
		for caption: Label in cell.find_children("*", "Label", true, false):
			check(cell.get_global_rect().grow(1).encloses(caption.get_global_rect()) and caption.get_visible_line_count() == caption.get_line_count(), context + " keeps stat text inside its card")
	for key in after:
		if key == "cost" or not (after[key] is int or after[key] is float): continue
		var number := details.find_child("Stat_" + key, true, false) as Label
		check(number != null and number.text.begins_with(UI.exact_money(after[key])), context + " displays next " + key)
		var change := details.find_child("Change_" + key, true, false) as Label
		if tower.level < Balance.MAX_TOWER_LEVEL:
			check(change != null, context + " compares " + key)
			var difference: float = after[key] - before.get(key, 0.0)
			if change != null:
				check(change.text == "No change" if is_zero_approx(difference) else change.text.begins_with("+" if difference > 0 else "−"), context + " signs " + key)
		else:
			check(change == null, context + " max tier does not invent improvements")
	check(Rect2(Vector2.ZERO, host.size).grow(1).encloses(dialog.card.get_global_rect()), context + " fits the viewport")
	check(dialog.card.get_global_rect().encloses(dialog.confirm.get_global_rect()) and dialog.confirm.is_visible_in_tree(), context + " pins the purchase action")
	check(dialog.card.get_global_rect().encloses(dialog.header_close.get_global_rect()), context + " keeps close reachable")
	check(dialog.scroll.get_h_scroll_bar().max_value <= dialog.scroll.get_h_scroll_bar().page + 1, context + " has no horizontal overflow")
	if tower.level == Balance.MAX_TOWER_LEVEL:
		check(dialog.confirm.disabled and dialog.confirm.text == "Max level", context + " prevents a fifth level")

func verify_scroll(host: Control, context: String) -> void:
	var dialog: VigilTowerDialog = host.tower_dialog
	var grid := dialog.body.find_child("TowerStats", true, false)
	var last: Control = grid.get_child(grid.get_child_count() - 1)
	dialog.scroll.scroll_vertical = 100000
	await process_frame
	await process_frame
	check(dialog.scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), context + " scroll reaches the final stat card")
	check(dialog.card.get_global_rect().encloses(dialog.confirm.get_global_rect()) and dialog.card.get_global_rect().encloses(dialog.header_close.get_global_rect()), context + " keeps purchase and close pinned while scrolling")
	dialog.scroll.scroll_vertical = 0
	await process_frame
	await process_frame

func exercise(host: Control, select: Callable, tower: Dictionary, context: String) -> void:
	for touch in [false, true]:
		host.panels.close_sheet()
		host.field.camera = VigilWorld.pad_position(tower.region, tower.pad)
		host.field.queue_redraw()
		await settle()
		var point: Vector2 = host.field.global_position + host.field.screen(VigilWorld.pad_position(tower.region, tower.pad))
		await Harness.tap(host, point, touch)
		await settle()
		if host.tower_actions.upgrade_in_dialog:
			check(not host.tower_dialog.visible and host.tower_actions.visible, context + " actual mouse/touch tower tap shows controls only")
			check(not host.tower_actions.upgrade_quote.visible and not host.tower_actions.branch_bar.visible, context + " hides inline upgrade banner and branch controls")
			await Harness.tap(host, host.tower_actions.buttons.upgrade.get_global_rect().get_center(), touch)
			await settle()
		check(host.tower_dialog.visible and host.tower_dialog.mode == "preview", context + " actual mouse/touch opens upgrade details through its mode entry point")
		check(not host.tower_actions.visible, context + " preview hides all surrounding actions")
		host.tower_dialog.dismiss()
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await settle()
		for kind in Balance.TOWERS:
			tower.kind = kind
			for level in [1, 2, 3, 4]:
				tower.level = level
				tower.branch = str(Balance.BRANCHES[kind].keys()[0]) if level == 4 else ""
				var gold: float = host.game.data.balance
				select_preview(host, select)
				await settle()
				verify_preview(host, tower, "%s %s level %d %s" % [context, kind, level, viewport])
				check(host.game.data.balance == gold and tower.level == level, context + " opening spends nothing and does not upgrade")
				if level == 3:
					for branch in Balance.BRANCHES[kind]:
						host.tower_dialog.find_child("Preview_" + branch, true, false).pressed.emit()
						await settle()
						verify_preview(host, tower, context + " " + branch)
						check(host.game.data.balance == gold and tower.level == level and tower.branch.is_empty(), context + " specialization selection only previews")
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://artifacts/upgrade-cards-%s-%s-%d.png" % [context, branch, viewport.x])
				if level in [1, 3]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/upgrade-preview-%s-%s-%d-%d.png" % [context, kind, level, viewport.x])
				await verify_scroll(host, "%s %s level %d %s" % [context, kind, level, viewport])
				host.tower_dialog.dismiss()
				check(host.tower_actions.visible, context + " closing exposes existing tower controls")
	# Tuned deltas and guarded purchases use the active mode's economy.
	tower.kind = "rapid"
	tower.level = 1
	tower.branch = ""
	host.game.data.settings.developer_balance = {"towers": {"rapid": {"damage": 10.0, "period": 1.0}, "rapid:2": {"damage": 18.0, "period": 0.5, "cost": 123.0}}}
	select_preview(host, select)
	await settle()
	var dialog: VigilTowerDialog = host.tower_dialog
	check(dialog.body.find_child("Change_damage", true, false).text == "+8", context + " damage delta follows tuned tiers")
	check(dialog.body.find_child("Change_fire_rate", true, false).text == "+1", context + " derived fire rate delta is next minus current")
	check(dialog.body.find_child("Change_dps", true, false).text == "+26", context + " derived DPS delta is next minus current")
	check(dialog.body.find_child("Change_period", true, false).text == "−0.5 s", context + " shorter intervals show a reduction")
	host.game.data.relics["preview_lantern"] = "matriarch_lantern"
	tower.relic = "preview_lantern"
	dialog.refresh()
	check(dialog.body.find_child("Stat_range", true, false).text == "184.8 units" and dialog.body.find_child("Change_range", true, false).text == "+16.8 units", context + " equipment applies to both sides of the comparison")
	tower.relic = ""
	host.game.data.relics.erase("preview_lantern")
	dialog.refresh()
	check(dialog.body.find_child("Change_range", true, false).text == "+14 units", context + " removing equipment refreshes the comparison")
	var old_revision := dialog.revision
	host.game.data.settings.developer_balance.towers["rapid:2"].cost = 124.0
	var gold: float = host.game.data.balance
	dialog.commit(old_revision)
	check(tower.level == 1 and host.game.data.balance == gold and dialog.confirm.text.contains("124 gold"), context + " stale price refreshes without purchasing")
	host.game.data.balance = 0.0
	dialog.refresh()
	check(dialog.visible and dialog.confirm.disabled, context + " insufficient funds preserve readable preview")
	dialog.commit(dialog.revision)
	check(tower.level == 1, context + " cannot buy with insufficient funds")
	host.game.data.balance = 10000.0
	tower.rebuild_remaining = 10.0
	dialog.refresh()
	check(dialog.rebuild_status.visible and dialog.confirm.disabled, context + " rebuilding blocks purchase")
	tower.rebuild_remaining = 0.0
	dialog.refresh()
	old_revision = dialog.revision
	await Harness.tap(host, dialog.confirm.get_global_rect().get_center(), context == "campaign")
	await settle()
	check(tower.level == 2 and host.game.data.balance == 9876.0, context + " explicit purchase charges the displayed quote once")
	if host.tower_actions.upgrade_in_dialog:
		check(not dialog.visible and not host.tower_actions.visible and host.field.selected_tower.is_empty(), context + " purchase closes details and clears selection")
	dialog.commit(old_revision)
	check(tower.level == 2 and host.game.data.balance == 9876.0, context + " repeated old action cannot purchase again")
	tower.level = 3
	select_preview(host, select)
	dialog.find_child("Preview_thorn_volley", true, false).pressed.emit()
	await settle()
	var quote := Balance.upgrade_cost(tower, host.game.tuning, "thorn_volley")
	gold = host.game.data.balance
	dialog.confirm.pressed.emit()
	check(tower.level == 4 and tower.branch == "thorn_volley" and host.game.data.balance == gold - quote, context + " buys only the previewed specialization")
	select_preview(host, select)
	dialog.confirm.pressed.emit()
	check(tower.level == 4, context + " maximum level cannot be purchased")
	dialog.dismiss()
	host.game.data.settings.developer_balance = {}

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://upgrade-preview-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.field.set_process(false)
	app.game.data.balance = 100000
	app.game.expand("1,0")
	var id := app.game.economy.build("rapid", "0,0", 1)
	await settle()
	await exercise(app, func(): app.panels.select_pad("0,0", 1), app.game.data.towers[id], "infinite")
	app.panels.close_sheet()
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.start_mission(0)
	campaign.field.set_process(false)
	campaign.game.data.balance = 100000
	var socket: int = campaign.run.mission.sockets[1].index
	campaign.run.build(socket, "rapid")
	id = campaign.run.tower_at(socket)
	await settle()
	await exercise(campaign, func(): campaign.show_socket(socket), campaign.game.data.towers[id], "campaign")
	app.free()
	print("TOWER UPGRADE PREVIEW: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
