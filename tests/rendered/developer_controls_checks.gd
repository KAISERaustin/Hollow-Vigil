extends RefCounted

static func run(app: VigilApp, harness: Script, failures: Array[String]) -> void:
	app.set_process(false)
	app.panels.show_settings()
	await settle(app)
	var open := app.panels.find_child("OpenDeveloperControls", true, false) as Button
	app.panels.content_scroll.ensure_control_visible(open)
	await settle(app)
	await harness.tap(app, open.get_global_rect().get_center())
	if app.panels.mode != "developer":
		failures.append("Settings did not open Developer Controls")
		return
	await settle(app)
	var controls := app.panels.find_child("DeveloperControls", true, false)
	if controls.category_list.get_child_count() != 5 or controls.editor.visible:
		failures.append("Developer home must show five categories and no editor")
	await harness.capture(app, "developer-categories")
	app.panels.content_scroll.ensure_control_visible(controls.tabs.enemies)
	await settle(app)
	await harness.tap(app, controls.tabs.enemies.get_global_rect().get_center())
	await settle(app)
	if controls.category != "enemies" or not controls.editor.visible or controls.category_list.visible:
		failures.append("Enemy category did not open its editor")
	var number: SpinBox = controls.inputs.hp
	app.panels.content_scroll.ensure_control_visible(number.get_parent())
	await settle(app)
	var camera := app.field.camera
	var previous := number.value
	var adjustment := number.get_parent().get_child(1)
	await harness.tap(app, adjustment.get_child(1).get_global_rect().get_center())
	if number.value != previous + number.step or app.game.tuning.enemies.basic.hp != number.value:
		failures.append("Mouse plus button did not change live enemy health")
	previous = number.value
	await harness.tap(app, adjustment.get_child(0).get_global_rect().get_center(), true)
	if number.value != previous - number.step:
		failures.append("Touch minus button did not change enemy health")
	var entry := number.get_line_edit()
	entry.grab_focus()
	entry.text = "37"
	entry.text_submitted.emit(entry.text)
	await settle(app)
	if number.value != 37 or app.game.tuning.enemies.basic.hp != 37:
		failures.append("Typed value did not change live enemy health")
	adjustment.get_child(1).grab_focus()
	previous = number.value
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await settle(app)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await settle(app)
	if number.value != previous + number.step:
		failures.append("Keyboard did not activate the focused plus button")
	app._process(0.4)
	var autosaved := app.game.storage.read_candidate(app.game.save_path)
	if autosaved.is_empty() or not preload("res://tests/unit/developer_tier_checks.gd").same_values(autosaved.settings.developer_balance, app.game.tuning):
		failures.append("Value debounce did not automatically save changes")
	if camera != app.field.camera:
		failures.append("Developer inputs moved the battlefield camera")
	for category in Balance.TUNING_FIELDS:
		controls.show_category(category)
		for index in range(controls.selector.item_count):
			controls.selector.select(index)
			controls.selector.item_selected.emit(index)
			if controls.inputs.size() != Balance.fields_for(category, controls.selected_kind).size():
				failures.append("A unit type is missing balance inputs")
			for stat in controls.inputs:
				var input: SpinBox = controls.inputs[stat]
				input.value = input.min_value + (input.max_value - input.min_value) * 0.4
				if not is_equal_approx(Balance.tuned_value(category, controls.selected_kind, stat, app.game.tuning), input.value):
					failures.append("Input did not edit its selected type: " + controls.selected_kind + "/" + stat)
		await settle(app)
	controls.show_category("bosses")
	await settle(app)
	await harness.capture(app, "developer-bosses")
	app.panels.content_scroll.ensure_control_visible(controls.inputs.regrowth_suppression)
	await settle(app)
	await harness.capture(app, "developer-boss-counters")
	controls.show_category("towers")
	await harness.capture(app, "developer-towers")
	var reset_selected: Button = controls.find_child("ResetSelectedBalance", true, false)
	app.panels.content_scroll.ensure_control_visible(reset_selected)
	await settle(app)
	await settle(app)
	await harness.tap(app, reset_selected.get_global_rect().get_center(), true)
	if app.game.tuning.towers.has("rapid") or not app.game.tuning.towers.has("heavy"):
		failures.append("Reset selected button changed the wrong unit types")
	# Closing flushes even when the debounce has not run.
	app.panels.show_settings()
	var saved := app.game.storage.read_candidate(app.game.save_path)
	if saved.is_empty() or not preload("res://tests/unit/developer_tier_checks.gd").same_values(saved.settings.developer_balance, app.game.tuning):
		failures.append("Leaving Developer Controls did not save the latest numeric values")
	app.panels.show_developer_controls()
	await settle(app)
	controls = app.panels.find_child("DeveloperControls", true, false)
	controls.show_category("enemies")
	if controls.inputs.hp.value != app.game.tuning.enemies.basic.hp:
		failures.append("Reopening Developer Controls did not restore numeric values")
	await harness.capture(app, "developer-enemies")
	var reset_all: Button = controls.find_child("ResetAllBalance", true, false)
	app.panels.content_scroll.ensure_control_visible(reset_all)
	await settle(app)
	await harness.tap(app, reset_all.get_global_rect().get_center(), true)
	if controls.inputs.hp.value != Balance.ENEMIES.basic.hp or not app.game.tuning.is_empty():
		failures.append("Reset did not restore displayed default values")
	# Reproduce a typed HP edit followed immediately by each way out, without Enter.
	var helpers := preload("res://tests/test_runner.gd").new()
	var enemy: Dictionary = helpers.fixture_enemy(app.game)
	for destination in ["close", "settings", "category", "type", "home"]:
		app.panels.show_developer_controls()
		controls = app.panels.find_child("DeveloperControls", true, false)
		controls.show_category("enemies")
		app.game.reset_developer_balance()
		controls.show_fields()
		var hp: SpinBox = controls.inputs.hp
		hp.get_line_edit().grab_focus()
		hp.get_line_edit().text = "400"
		match destination:
			"close": app.panels.close_sheet()
			"settings": app.panels.show_settings()
			"category": controls.show_category("bosses")
			"type":
				controls.selector.select(1)
				controls.selector.item_selected.emit(1)
			"home": controls.show_categories()
		if enemy.hp != 400.0 or enemy.max_hp != 400.0:
			failures.append("Typed 45 to 400 HP edit lost on " + destination)
		if destination in ["close", "settings"]:
			var snapshot := app.game.storage.read_candidate(app.game.save_path)
			if snapshot.get("settings", {}).get("developer_balance", {}).get("enemies", {}).get("basic", {}).get("hp", 0) != 400.0:
				failures.append("Typed HP not saved on " + destination)
	app.panels.show_developer_controls()
	controls = app.panels.find_child("DeveloperControls", true, false)
	controls.find_child("ShowHealthNumbers", true, false).button_pressed = true
	if not app.field.show_health_numbers:
		failures.append("Health overlay toggle did not enable live HP numbers")
	app.panels.close_sheet()
	app.field.camera = enemy.pos
	app.field.queue_redraw()
	await settle(app)
	await harness.capture(app, "developer-live-400-hp")
	helpers.free()
	app.game.reset_developer_balance()
	app.set_process(true)
	print("DEVELOPER_CONTROLS: mouse, touch, keyboard, every type, save and reopen checked")

static func settle(app: Control) -> void:
	for i in range(6):
		await app.get_tree().process_frame
