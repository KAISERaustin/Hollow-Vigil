extends RefCounted

static func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

static func run(app: Control, harness: Script, failures: Array[String]) -> void:
	app.set_process(false)
	var original: VigilState = app.game
	var old_camera: Vector2 = app.field.camera
	var old_zoom: float = app.field.zoom
	var window := app.get_window()
	var old_size := window.size
	var old_scale := window.content_scale_size
	app.panels.close_sheet()
	for viewport in [Vector2i(540, 960), Vector2i(360, 640)]:
		window.content_scale_size = viewport
		window.size = viewport
		await app.get_tree().process_frame
		await app.get_tree().process_frame
		for kind in Balance.TOWERS:
			for touch in [false, true]:
				var g := VigilState.new(784)
				g.save_path = "user://relocation-ui.save"
				g.data.balance = 10000.0
				var id := g.economy.build(kind, "0,0", 0)
				g.economy.build("rapid", "0,0", 1)
				app.game = g
				app.field.state = g
				app.field.zoom = 1.0
				app.field.camera = VigilWorld.pad_position("0,0", 0)
				app.panels.select_pad("0,0", 0)
				g.economy.credit(id, 17.5)
				app.toast_label.modulate.a = 0
				var before := g.data.duplicate(true)
				var dialog = app.tower_dialog
				for action in ["info", "upgrade", "sell", "move"]:
					check(app.tower_actions.buttons.has(action), "Tower menu is missing " + action, failures)
				await harness.tap(app, app.tower_actions.buttons.move.get_global_rect().get_center(), touch)
				check(dialog.visible and dialog.mode == "move", "Mouse/touch could not open Move", failures)
				check(dialog.cost == Balance.move_cost(g.data.towers[id]) and dialog.rebuild_seconds == Balance.rebuild_seconds(g.data.towers[id]), "Move quote disagrees with the economy", failures)
				g.data.balance = 0
				dialog.refresh()
				check(dialog.confirm.disabled, "Unaffordable relocation remained actionable", failures)
				g.data.balance = before.balance
				dialog.refresh()
				if not touch:
					await harness.capture(app, "relocation-quote-%s-%d" % [kind, viewport.x])
				await harness.tap(app, dialog.cancel.get_global_rect().get_center(), touch)
				check(g.data == before and app.field.moving_tower == "", "Cancelling quote changed the tower or gold", failures)
				await harness.tap(app, app.tower_actions.buttons.move.get_global_rect().get_center(), touch)
				var stale: Callable = dialog.confirm.pressed.get_connections()[0].callable
				await harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
				stale.call()
				check(app.tower_move.visible and app.field.moving_tower == id and not dialog.visible and not app.tower_actions.visible and g.data == before, "Choosing a destination spent early or left other controls active", failures)
				check(app.field.get_global_rect().encloses(app.tower_move.get_global_rect()), "Move instructions overflow the map", failures)
				check(app.tower_move.cancel_button.size.x >= 48 and app.tower_move.cancel_button.size.y >= 48, "Move Cancel is smaller than a touch target", failures)
				await harness.tap(app, app.field.global_position + app.field.screen(VigilWorld.pad_position("0,0", 0)), touch)
				check(g.data == before and app.tower_move.visible, "Occupied socket charged gold or cancelled destination selection", failures)
				await harness.tap(app, app.tower_move.cancel_button.get_global_rect().get_center(), touch)
				check(g.data == before and app.field.moving_tower == "" and app.tower_actions.visible, "Cancelling destination selection failed", failures)
				await harness.tap(app, app.tower_actions.buttons.move.get_global_rect().get_center(), touch)
				await harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
				app.field.camera = Vector2.ZERO
				app.toast_label.modulate.a = 0
				if not touch:
					await harness.capture(app, "relocation-pick-%s-%d" % [kind, viewport.x])
				var destination: Vector2 = app.field.global_position + app.field.screen(VigilWorld.pad_position("0,0", 3))
				await harness.tap(app, destination, touch)
				app.tower_move.place("0,0", 2)
				check(g.data.towers[id].pad == 3 and g.data.balance == before.balance - Balance.move_cost(before.towers[id]), "Placement failed or duplicate callback charged twice", failures)
				check(g.data.towers[id].earnings == 17.5 and g.data.towers[id].rebuild_remaining > 0 and not app.tower_move.visible, "Placement lost earnings or failed to start rebuilding", failures)
				var saved: Dictionary = g.storage.read_candidate(g.save_path)
				check(not saved.is_empty() and saved.towers[id].pad == 3 and saved.towers[id].rebuild_remaining == g.data.towers[id].rebuild_remaining, "UI placement did not persist its destination and timer", failures)
				app.toast_label.modulate.a = 0
				if not touch:
					await harness.capture(app, "relocation-rebuild-%s-%d" % [kind, viewport.x])
				for action in ["move", "upgrade"]:
					dialog.open_action(action)
					check((app.tower_actions.buttons.upgrade.disabled and not dialog.visible) if action == "upgrade" else (dialog.confirm.disabled and dialog.rebuild_status.visible), "Rebuilding tower offered an actionable move or upgrade", failures)
					dialog.dismiss()
				g.data.towers[id].rebuild_remaining = 0
				app.tower_move.begin(id, 1, Balance.move_cost(g.data.towers[id]), Balance.rebuild_seconds(g.data.towers[id]))
				var escape := InputEventKey.new()
				escape.keycode = KEY_ESCAPE
				escape.pressed = true
				app._input(escape)
				check(not app.tower_move.visible and app.field.moving_tower == "", "Escape failed to cancel moving", failures)
				app.tower_move.begin(id, 1, Balance.move_cost(g.data.towers[id]), Balance.rebuild_seconds(g.data.towers[id]))
				g.economy.upgrade(id, 1)
				var changed := g.data.duplicate(true)
				app.tower_move.place("0,0", 2)
				check(g.data == changed and app.field.moving_tower == "", "A stale move quote charged after the tower changed", failures)
				app.tower_move.begin(id, 2, Balance.move_cost(g.data.towers[id]), Balance.rebuild_seconds(g.data.towers[id]))
				app.panels.show_settings()
				check(not app.tower_move.visible and app.field.moving_tower == "", "Opening Settings left a stale move active", failures)
				app.panels.close_sheet()
	window.content_scale_size = old_scale
	window.size = old_size
	app.game = original
	app.field.state = original
	app.field.camera = old_camera
	app.field.zoom = old_zoom
	app.update_hud()
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	app.set_process(true)
	print("RELOCATION_UI: all towers, mouse/touch, small/large viewports, quotes, cancellation, placement, rebuild restrictions and persistence checked")
