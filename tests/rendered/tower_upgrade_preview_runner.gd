extends "res://tests/rendered/campaign_runner.gd"

const Choice = preload("res://scripts/ui/towers/tower_choice.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")

func settle() -> void:
	for tick in 10: await process_frame

func verify_preview(host: Control, tower: Dictionary, context: String) -> void:
	var dialog: VigilTowerDialog = host.tower_dialog
	check(dialog.visible and dialog.mode == "preview", context + " opens upgrade details directly")
	check(dialog.find_child("TowerCards", true, false) == null, context + " skips the construction catalog")
	var details: Control = dialog.body.get_node("TowerDetails")
	var next_level := mini(int(tower.level) + 1, Balance.MAX_TOWER_LEVEL)
	var after := Balance.stats(tower.kind, next_level, host.game.tuning, dialog.tower_branch)
	var before := Balance.tower_stats(tower, host.game.tuning)
	var level_label := "Level %d" % next_level if tower.level == Balance.MAX_TOWER_LEVEL else "Level %d → %d" % [tower.level, next_level]
	check(details.get_node("TowerStats") != null and details.find_child("TowerLevel", true, false).text == level_label, context + " uses the build details at the next level")
	check(details.find_child("TowerDescription", true, false).text == Balance.tower_description(after), context + " describes the previewed tier")
	check(dialog.heading.text == after.name, context + " names the previewed tower")
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

func exercise(host: Control, select: Callable, tower: Dictionary, context: String) -> void:
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
				select.call()
				await settle()
				verify_preview(host, tower, "%s %s level %d %s" % [context, kind, level, viewport])
				check(host.game.data.balance == gold and tower.level == level, context + " opening spends nothing and does not upgrade")
				if level == 3:
					for branch in Balance.BRANCHES[kind]:
						host.tower_dialog.find_child("Preview_" + branch, true, false).pressed.emit()
						await settle()
						verify_preview(host, tower, context + " " + branch)
						check(host.game.data.balance == gold and tower.level == level and tower.branch.is_empty(), context + " specialization selection only previews")
				if kind == "rapid" and level in [1, 3]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/upgrade-preview-%s-%d-%d.png" % [context, level, viewport.x])
				host.tower_dialog.dismiss()
				check(host.tower_actions.visible, context + " closing exposes existing tower controls")
	# Tuned deltas and guarded purchases use the active mode's economy.
	tower.kind = "rapid"
	tower.level = 1
	tower.branch = ""
	host.game.data.settings.developer_balance = {"towers": {"rapid": {"damage": 10.0, "period": 1.0}, "rapid:2": {"damage": 18.0, "period": 0.5, "cost": 123.0}}}
	select.call()
	await settle()
	var dialog: VigilTowerDialog = host.tower_dialog
	check(dialog.body.find_child("Change_damage", true, false).text == "+8", context + " damage delta follows tuned tiers")
	check(dialog.body.find_child("Change_fire_rate", true, false).text == "+1", context + " derived fire rate delta is next minus current")
	check(dialog.body.find_child("Change_dps", true, false).text == "+26", context + " derived DPS delta is next minus current")
	check(dialog.body.find_child("Change_period", true, false).text == "−0.5 s", context + " shorter intervals show a reduction")
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
	dialog.commit(old_revision)
	check(tower.level == 2 and host.game.data.balance == 9876.0, context + " repeated old action cannot purchase again")
	tower.level = 3
	select.call()
	dialog.find_child("Preview_thorn_volley", true, false).pressed.emit()
	await settle()
	var quote := Balance.upgrade_cost(tower, host.game.tuning, "thorn_volley")
	gold = host.game.data.balance
	dialog.confirm.pressed.emit()
	check(tower.level == 4 and tower.branch == "thorn_volley" and host.game.data.balance == gold - quote, context + " buys only the previewed specialization")
	select.call()
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
