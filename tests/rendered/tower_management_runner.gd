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
		check(not dialog.header_close.is_visible_in_tree(), "No management close button")
		check(dialog.management_grid.get_child(0).get_child(2).name == "Manage_sell", "Sell occupies top right")
		check(dialog.confirm.size == Vector2(104, 48), "Upgrade spans two button slots")
		check(dialog.management_bottom.get_child(0).size == Vector2(48, 48), "Move retains touch size")
		var squares = dialog.level_display.get_node("LevelSquares")
		check(squares.vertical and squares.get_child_count() == 4, "Four vertical slots")
		check(dialog.level_holder.global_position.x < dialog.identity_card.global_position.x and dialog.identity_card.global_position.x < dialog.management_grid.global_position.x, "Slots identity actions order")
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
		var original_card_rect := dialog.card.get_global_rect()
		dialog.confirm.pressed.emit()
		await settle()
		check(dialog.mode == "info" and dialog.upgrade_armed, "Upgrade arms inline confirmation")
		check(not dialog.footer.visible, "No extra upgrade quote below management")
		check(dialog.card.get_global_rect() == original_card_rect, "Confirmation keeps management size and position")
		await Harness.capture(host, "tower-upgrade-confirm-" + prefix + "-" + str(viewport.x))
		check(host.game.data.towers[host.field.selected_tower].level == level, "Preview does not purchase")
		var balance: float = host.game.data.balance
		var quote: float = dialog.cost
		dialog.confirm.pressed.emit()
		await settle()
		check(host.game.data.towers[host.field.selected_tower].level == level + 1, "Checkmark upgrades directly")
		check(is_equal_approx(host.game.data.balance, balance - quote), "Charges quoted gold once")
		host.game.data.towers[host.field.selected_tower].level = level
		dialog.open_action("info")
		dialog.confirm.pressed.emit()
		dialog.go_back()
		await settle()
		dialog.go_back()
		check(not dialog.visible, "Back closes management")
		if viewport.x > 0:
			var tower: Dictionary = host.game.data.towers[host.field.selected_tower]
			for tier in range(1, 5):
				tower.level = tier
				tower.branch = "frostneedle" if tier == 4 else ""
				dialog.open_action("info")
				await settle()
				check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(dialog.card.get_global_rect()), "Every tier fits portrait")
				if tier >= 3:
					check(dialog.branch_cards.get_child_count() == 2, "Two illustrated branch choices")
					check(not dialog.identity_card.visible and dialog.confirm.visible and dialog.confirm.disabled, "Branch cards replace portrait and retain locked upgrade button")
					check(dialog.level_holder.get_global_rect().end.x <= dialog.branch_cards.get_global_rect().position.x and dialog.branch_cards.get_global_rect().end.x <= dialog.management_grid.get_global_rect().position.x, "Branch cards fit between level boxes and actions")
					check(dialog.card.get_global_rect().size.y <= 160, "Branch management remains compact")
					for choice in dialog.branch_cards.get_children():
						var caption: Label = choice.find_child("BranchCaption", true, false)
						check(" · " in caption.text and "gold" in caption.text and not "\n" in caption.text, "Tower and price share one line with a dot")
				await Harness.capture(host, "tower-management-" + prefix + "-level-" + str(tier))
				if tier == 3:
					var branch: String = Balance.BRANCHES[tower.kind].keys()[1]
					await tap(dialog.branch_cards.get_child(0).get_global_rect().get_center())
					await settle()
					await tap(dialog.branch_cards.get_child(1).get_global_rect().get_center())
					await settle()
					check(tower.level == 3 and dialog.tower_branch == branch, "Switching cards selects without purchasing")
					check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(dialog.card.get_global_rect()), "Branch confirmation fits portrait")
					await Harness.capture(host, "tower-upgrade-branch-" + prefix)
					var before: float = host.game.data.balance
					var price: float = dialog.cost
					await tap(dialog.branch_cards.get_child(1).get_global_rect().get_center())
					await settle()
					check(tower.level == 4 and tower.branch == branch, "Same card purchases selected specialization")
					check(is_equal_approx(host.game.data.balance, before - price), "Card charges once")
					check("Locked" in dialog.branch_cards.get_child(0).accessibility_name and "Selected" in dialog.branch_cards.get_child(1).accessibility_name, "Purchased and locked paths remain visible")
					await Harness.capture(host, "tower-branch-purchased-" + prefix + "-" + str(viewport.x))
				dialog.dismiss()
			tower.level = 1
			tower.branch = ""

		for touch in [false, true]:
			var buttons: Array = [host.speed_button, host.wave_button] if prefix == "campaign" else [host.hud.speed_button, host.hud.pause_button]
			for button in buttons:
				if prefix == "campaign":
					host.run.phase = "planning"
					host.refresh()
				select.call()
				await settle()
				dialog.confirm.pressed.emit()
				await settle()
				var activations := [0]
				var record := func(): activations[0] += 1
				button.pressed.connect(record)
				var button_point: Vector2 = button.get_global_rect().get_center()
				if touch:
					for pressed in [true, false]:
						var event := InputEventScreenTouch.new()
						event.position = button_point
						event.pressed = pressed
						Input.parse_input_event(event)
						await process_frame
				else:
					await Harness.tap(host, button_point)
				button.pressed.disconnect(record)
				check(activations[0] == 1, prefix + " external button activates exactly once on first tap")
				check(not dialog.visible, "External button dismisses armed upgrade menu")
			select.call()
			await settle()
			dialog.confirm.pressed.emit()
			await settle()
			var balance_before: float = host.game.data.balance
			var point: Vector2 = host.field.get_global_rect().position + Vector2(16, 16)
			if touch:
				for pressed in [true, false]:
					var event := InputEventScreenTouch.new()
					event.position = point
					event.pressed = pressed
					Input.parse_input_event(event)
					await process_frame
			else:
				await tap(point)
			check(dialog.dismissing, "Battlefield tap starts downward dismissal")
			await create_timer(0.25).timeout
			check(not dialog.visible, "Battlefield tap hides management")
			check(host.field.selected_tower == "", "Dismissal clears selection")
			check(host.game.data.balance == balance_before, "Dismissal never purchases armed upgrade")

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
