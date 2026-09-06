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
	var g := VigilState.new(879)
	g.save_path = "user://tower-panel-test.save"
	g.data.balance = 100000.0
	for region in ["-1,0", "0,-1", "1,0", "0,1"]:
		g.expand(region)
	var rapid := g.economy.build("rapid", "0,0", 0)
	var splash := g.economy.build("splash", "0,0", 1)
	var heavy := g.economy.build("heavy", "0,0", 2)
	g.data.towers[rapid].level = 2
	app.game = g
	app.field.state = g
	app.field.camera = Vector2.ZERO
	app.field.zoom = 1.0
	app.panels.close_sheet()
	app.toast_timer = 0.0
	app.toast_label.modulate.a = 0.0
	await app.get_tree().process_frame
	var dialog = app.tower_dialog
	for touch in [false, true]:
		g.data.balance = 10.0
		g.data.towers[rapid].level = 2
		g.data.towers[splash].earnings = 73.0
		g.data.reserve = 13.0
		g.economy.credit(rapid, 400.0)
		app.update_hud()
		var location: Vector2 = app.field.global_position + app.field.screen(VigilWorld.pad_position("0,0", 0))
		await harness.tap(app, location, touch)
		check(not app.panels.visible and app.tower_actions.visible and not dialog.visible, "Tower click should reveal the five in-world controls", failures)
		check(g.data.balance == 410.0 and g.data.towers[rapid].earnings == 0.0, "Tower click did not collect its stored gold exactly once", failures)
		check(g.data.towers[splash].earnings == 73.0 and g.data.reserve == 13.0, "Tower click collected another source's gold", failures)
		await harness.tap(app, location, touch)
		check(g.data.balance == 410.0, "Repeated tower click duplicated gold", failures)
		g.economy.credit(rapid, 25.0)
		for tower in g.data.towers.values():
			check(not app.field.earnings_badge_visible(tower), "Tower selection left an earnings badge visible", failures)
		if not touch:
			await harness.capture(app, "tower-badges-hidden")
		for action in ["info", "sell", "move", "target"]:
			var before: Dictionary = g.data.duplicate(true)
			await harness.tap(app, app.tower_actions.buttons[action].get_global_rect().get_center(), touch)
			check(dialog.visible and dialog.mode == action and not app.tower_actions.visible, "Action icon did not open the correct modal", failures)
			check(not app.field.earnings_badge_visible(g.data.towers[splash]), "Opening a tower dialog restored other towers' gold badges", failures)
			check(dialog.card.get_global_rect().get_center().distance_to(app.size * 0.5) < 1.0, "Tower dialog is not centered", failures)
			var stale: Callable = dialog.confirm.pressed.get_connections()[0].callable
			await harness.tap(app, app.hud.collect_button.get_global_rect().get_center(), touch)
			await harness.tap(app, Vector2(4, 150), touch)
			check(dialog.visible and g.data == before, "Modal backdrop allowed a collection or transaction", failures)
			await harness.tap(app, (dialog.confirm if action == "info" else dialog.cancel).get_global_rect().get_center(), touch)
			stale.call()
			check(not dialog.visible and app.tower_actions.visible and g.data == before, "Cancel or its stale confirmation changed state", failures)
			check(not app.field.earnings_badge_visible(g.data.towers[splash]), "Returning to tower controls restored gold badges too early", failures)
		await harness.tap(app, app.tower_actions.buttons.info.get_global_rect().get_center(), touch)
		var before_info: Dictionary = g.data.duplicate(true)
		await harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
		check(g.data == before_info and not dialog.visible, "Confirming Info changed the tower", failures)
		for target_mode in Balance.TARGET_MODES:
			await harness.tap(app, app.tower_actions.buttons.target.get_global_rect().get_center(), touch)
			check(dialog.find_child("Target_" + g.data.towers[rapid].target_mode, true, false).button_pressed, "Targeting dialog did not show the saved choice", failures)
			var before_targeting := g.data.duplicate(true)
			await harness.tap(app, dialog.find_child("Target_" + target_mode, true, false).get_global_rect().get_center(), touch)
			for key in Balance.TARGET_MODES:
				var choice: Button = dialog.find_child("Target_" + key, true, false)
				check(choice.button_pressed == (key == target_mode), "Only the selected targeting mode should be highlighted", failures)
				check(choice.get_theme_stylebox("pressed").bg_color == Color(VigilTowerDialog.UI.GOLD) and choice.get_theme_stylebox("hover_pressed").bg_color == Color(VigilTowerDialog.UI.GOLD), "Selected targeting mode should remain yellow on hover", failures)
			check(g.data == before_targeting, "Target choice changed state before Apply", failures)
			await harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
			check(g.data.towers[rapid].target_mode == target_mode and g.data.towers[splash].target_mode == "first", "Targeting did not apply independently", failures)
			var target_save: Dictionary = g.storage.read_candidate(g.save_path)
			check(not target_save.is_empty() and target_save.towers[rapid].target_mode == target_mode, "Target choice was not saved", failures)
		var upgrade_button: Button = app.tower_actions.buttons.upgrade
		var upgrade_rect := upgrade_button.get_global_rect()
		await harness.tap(app, upgrade_rect.get_center(), touch)
		await harness.tap(app, app.tower_actions.buttons.info.get_global_rect().get_center(), touch)
		check(app.tower_actions.pending_tower == "", "Another action retained upgrade confirmation", failures)
		await harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
		await harness.tap(app, upgrade_rect.get_center(), touch)
		app.field.selected_tower = splash
		app.field.selected_tower = rapid
		check(app.tower_actions.pending_tower == "", "Changing towers retained upgrade confirmation", failures)
		await harness.tap(app, upgrade_rect.get_center(), touch)
		check(not dialog.visible and app.tower_actions.pending_tower == rapid and g.data.towers[rapid].level == 2, "First click must only arm inline confirmation", failures)
		check(upgrade_button.get_global_rect() == upgrade_rect, "Confirmation moved the button", failures)
		g.data.balance = 99.0
		app.tower_actions.refresh()
		check(upgrade_button.disabled, "Unaffordable confirmation enabled", failures)
		g.data.balance = 410.0
		app.tower_actions.refresh()
		check(not upgrade_button.disabled, "Affordable confirmation disabled", failures)
		await harness.capture(app, "tower-inline-confirm-" + str(touch))
		await harness.tap(app, upgrade_rect.get_center(), touch)
		check(g.data.towers[rapid].level == 3 and g.data.balance == 310.0 and g.data.towers[rapid].earnings == 25.0, "Inline upgrade charged incorrectly", failures)
		check(app.tower_actions.pending_tower == "" and not upgrade_button.disabled, "Level three should offer branch selection", failures)
		var capped := g.data.duplicate(true)
		upgrade_button.pressed.emit()
		check(g.data == capped and not dialog.visible, "Opening branch choices changed state", failures)
		var upgrade_save: Dictionary = g.storage.read_candidate(g.save_path)
		check(not upgrade_save.is_empty() and upgrade_save.towers[rapid].level == 3, "Upgrade was not saved", failures)
		# A hidden badge must act like the ground beneath it, not collect gold.
		var hidden_badge: Rect2 = app.field.earnings_rect(g.data.towers[splash])
		await harness.tap(app, app.field.global_position + hidden_badge.get_center(), touch)
		check(app.field.selected_tower == "" and not app.tower_actions.visible, "Clicking away did not dismiss tower controls", failures)
		check(g.data.towers[splash].earnings == 73.0, "A hidden gold badge intercepted the click-away and collected gold", failures)
		check(app.field.earnings_badge_visible(g.data.towers[rapid]) and app.field.earnings_badge_visible(g.data.towers[splash]), "Clicking away did not restore every eligible earnings badge", failures)
		if not touch:
			await harness.capture(app, "tower-badges-restored")
		await harness.tap(app, app.field.global_position + hidden_badge.get_center(), touch)
		check(g.data.towers[splash].earnings == 0.0, "Restored earnings badge could not collect gold", failures)
		g.economy.collect()
	g.economy.credit(splash, 11.0)
	app.panels.select_pad("0,0", 0)
	app.panels.show_settings()
	check(app.field.earnings_badge_visible(g.data.towers[splash]), "Leaving tower controls for another panel did not restore gold badges", failures)
	app.panels.close_sheet()
	g.economy.collect()
	g.data.balance = 2000.0
	g.data.towers[rapid].level = 2
	app.field.camera = VigilWorld.pad_position("0,0", 0)
	app.panels.select_pad("0,0", 0)
	var reference_layout := {}
	for action in app.tower_actions.buttons:
		var rect: Rect2 = app.tower_actions.buttons[action].get_rect()
		reference_layout[action] = Rect2(rect.position - app.field.size * 0.5, rect.size)
	for viewport in [Vector2i(540, 960), Vector2i(420, 800), Vector2i(360, 640)]:
		window.content_scale_size = viewport
		window.size = viewport
		await app.get_tree().process_frame
		await app.get_tree().process_frame
		for id in [rapid, splash, heavy]:
			# Pan explicitly to exercise the controls without selection moving the camera.
			app.field.camera = VigilWorld.pad_position("0,0", int(g.data.towers[id].pad))
			app.panels.select_pad("0,0", int(g.data.towers[id].pad))
			await harness.capture(app, "tower-actions-%s-%d" % [g.data.towers[id].kind, viewport.x])
			for action in ["info", "sell", "move", "target"]:
				await harness.tap(app, app.tower_actions.buttons[action].get_global_rect().get_center(), true)
				await harness.capture(app, "tower-%s-%s-%d" % [action, g.data.towers[id].kind, viewport.x])
				check(dialog.visible, "Tower icon inaccessible at %s" % viewport, failures)
				check(dialog.card.get_global_rect().get_center().distance_to(app.size * 0.5) < 1.0, "Dialog is off-center at %s" % viewport, failures)
				check(Rect2(Vector2.ZERO, app.size).encloses(dialog.card.get_global_rect()), "Dialog overflows the screen at %s" % viewport, failures)
				check(dialog.card.get_global_rect().encloses(dialog.confirm.get_global_rect()) and (not dialog.cancel.visible or dialog.card.get_global_rect().encloses(dialog.cancel.get_global_rect())), "Dialog confirmation buttons are clipped", failures)
				check(dialog.body.size.x <= dialog.scroll.size.x, "Dialog text overflows horizontally", failures)
				for control in dialog.find_children("*", "Control", true, false):
					check(control.tooltip_text.is_empty(), "Tower dialog contains unwanted hover text", failures)
				if action == "upgrade":
					check(dialog.find_child("TowerStats", true, false) == null, "Upgrade should show compact controls; stats belong in Info", failures)
				await harness.tap(app, (dialog.confirm if action == "info" else dialog.cancel).get_global_rect().get_center(), true)
		# Controls retain their map size and tower-relative offsets, even at edges.
		for zoom in [0.42, 0.65, 1.0, 1.65]:
			app.field.zoom = zoom
			for id in [rapid, splash, heavy]:
				var pad: int = g.data.towers[id].pad
				var world := VigilWorld.pad_position("0,0", pad)
				for edge in [Vector2(4, 4), Vector2(app.field.size.x - 4, 4), app.field.size - Vector2(4, 4), Vector2(4, app.field.size.y - 4), app.field.size * 0.5]:
					app.field.camera = world - (edge - app.field.size * 0.5) / zoom
					var before_camera: Vector2 = app.field.camera
					app.panels.select_pad("0,0", pad)
					await app.get_tree().process_frame
					check(app.field.camera.is_equal_approx(before_camera) and app.field.zoom == zoom, "Selecting a tower moved or zoomed the camera", failures)
					check_layout(app, reference_layout, failures)
				app.field.camera += Vector2(12, 8)
				app.tower_actions.refresh()
				check_layout(app, reference_layout, failures)
				if id == rapid:
					g.economy.credit(rapid, 1900.0)
					await harness.capture(app, "tower-actions-zoom-%.2f-%d" % [zoom, viewport.x])
					check(not app.field.earnings_badge_visible(g.data.towers[rapid]), "New earnings appeared during tower selection at zoom %.2f" % zoom, failures)
					app.panels.close_sheet()
					check(app.field.earnings_badge_visible(g.data.towers[rapid]), "Closing tower controls failed to restore gold at zoom %.2f" % zoom, failures)
					var before_collection: float = g.data.balance
					var badge: Rect2 = app.field.earnings_rect(g.data.towers[rapid])
					await harness.tap(app, app.field.global_position + badge.get_center(), true)
					check(g.data.towers[rapid].earnings == 0.0 and g.data.balance == before_collection + 1900.0, "Tower-relative earnings badge did not collect at zoom %.2f" % zoom, failures)
					app.panels.select_pad("0,0", 0)
					for touch in [false, true]:
						for action in ["info", "sell", "move", "target"]:
							await harness.tap(app, app.tower_actions.buttons[action].get_global_rect().get_center(), touch)
							check(dialog.visible and dialog.mode == action, "Tower-relative action failed at zoom %.2f" % zoom, failures)
							await harness.tap(app, (dialog.confirm if action == "info" else dialog.cancel).get_global_rect().get_center(), touch)
		app.field.zoom = 1.0
	# Real zoom scales tower controls with the map while the HUD stays fixed.
	app.field.camera = VigilWorld.pad_position("0,0", 0)
	app.panels.select_pad("0,0", 0)
	var hud_rects := {}
	for control in [app.hud.gold_label, app.hud.rate_label, app.hud.kills_label, app.hud.collect_button, app.toast_label]:
		hud_rects[control] = control.get_global_rect()
	for zoom in [0.42, 1.65, 0.65, 1.0]:
		app.field.set_zoom(zoom, app.field.size * 0.5)
		await app.get_tree().process_frame
		check_layout(app, reference_layout, failures)
		for control in hud_rects:
			check(control.get_global_rect().is_equal_approx(hud_rects[control]), "Camera zoom changed the HUD layout", failures)
	# Sale includes earnings generated after opening the dialog and persists the empty socket.
	app.field.zoom = 1.0
	app.field.camera = Vector2.ZERO
	app.panels.select_pad("0,0", 0)
	var before_sale: float = g.data.balance
	var refund := Balance.sell_refund(g.data.towers[rapid])
	await harness.tap(app, app.tower_actions.buttons.sell.get_global_rect().get_center())
	g.economy.credit(rapid, 17.0)
	app.update_hud()
	var sale: Callable = dialog.confirm.pressed.get_connections()[0].callable
	await harness.tap(app, dialog.confirm.get_global_rect().get_center())
	sale.call()
	check(not g.data.towers.has(rapid) and g.data.balance == before_sale + refund + 17.0, "Confirmed sale failed or paid twice", failures)
	check(not dialog.visible and not app.tower_actions.visible and app.field.selected_tower == "", "Sale left stale tower controls", failures)
	var saved: Dictionary = g.storage.read_candidate(g.save_path)
	check(not saved.is_empty() and not saved.towers.has(rapid) and saved.balance == g.data.balance, "Sold tower or refund did not persist", failures)
	await harness.tap(app, app.field.global_position + app.field.screen(VigilWorld.pad_position("0,0", 0)))
	check(app.panels.mode == "build", "Sold socket cannot be rebuilt", failures)
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
	print("TOWER_CONTROLS: tower-relative actions, hidden gold badges during selection and dialogs, click-away restoration and collection, no selection camera movement, mouse/touch at four zooms and three viewport sizes, stable HUD, centered modals, upgrade, sale and persistence checked")

static func check_layout(app: Control, reference_layout: Dictionary, failures: Array[String]) -> void:
	var tower: Dictionary = app.game.data.towers[app.field.selected_tower]
	var center: Vector2 = app.field.global_position + app.field.screen(VigilWorld.pad_position(tower.region, tower.pad))
	for action in reference_layout:
		var rect: Rect2 = app.tower_actions.buttons[action].get_global_rect()
		check((rect.size / app.field.zoom).is_equal_approx(reference_layout[action].size), "World zoom changed the map size of the " + action + " button", failures)
		check(((rect.position - center) / app.field.zoom).is_equal_approx(reference_layout[action].position), "Pan or zoom detached the " + action + " button from its tower", failures)
