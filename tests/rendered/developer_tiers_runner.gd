extends SceneTree

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://developer-tiers-ui.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var harness = preload("res://tests/rendered/visual_smoke.gd")
	var checks = preload("res://tests/rendered/developer_controls_checks.gd")
	var failures: Array[String] = []
	app.game.data.first_property_required = false
	await checks.settle(app)
	await checks.run(app, harness, failures)
	app.set_process(false)
	app.panels.show_developer_controls()
	await checks.settle(app)
	var controls = app.panels.find_child("DeveloperControls", true, false)
	controls.show_category("towers")
	for family in range(controls.selector.item_count):
		controls.selector.select(family)
		controls.selector.item_selected.emit(family)
		if controls.tier_selector.item_count != 5:
			failures.append("Tower lacks all three tiers and both branches")
		for tier in range(controls.tier_selector.item_count):
			controls.tier_selector.select(tier)
			controls.tier_selector.item_selected.emit(tier)
			var key: String = controls.editing_kind()
			if controls.inputs.size() != Balance.editable_fields_for("towers", key).size():
				failures.append("Missing attributes for " + key)
			for stat in controls.inputs:
				var numeric := controls.fields.find_child(stat + "Value", true, false) as SpinBox
				numeric.value = numeric.min_value + numeric.step * 2
				if not is_equal_approx(Balance.configuration_value("towers", key, stat, app.game.tuning), numeric.value):
					failures.append("Numeric input failed for " + key + "/" + stat)
	controls.show_category("towers")
	controls.tier_selector.select(3)
	controls.tier_selector.item_selected.emit(3)
	await checks.settle(app)
	await harness.capture(app, "developer-tier-frostneedle")
	app.panels.content_scroll.ensure_control_visible(controls.inputs.slow_duration)
	await checks.settle(app)
	await harness.capture(app, "developer-tier-frostneedle-abilities")
	for size in [Vector2i(360, 640), Vector2i(540, 960)]:
		root.size = size
		await checks.settle(app)
		if controls.get_global_rect().end.x > app.size.x + 1:
			failures.append("Developer controls overflow the viewport")
	app.panels.show_settings()
	var loaded := VigilState.new(56)
	loaded.save_path = app.game.save_path
	if not loaded.load_save() or not preload("res://tests/unit/developer_tier_checks.gd").same_values(loaded.tuning, app.game.tuning):
		failures.append("UI tier changes did not survive save/reload")
	app.panels.close_sheet()
	app.game.reset_developer_balance()
	app.game.data.first_property_required = false
	app.game.data.balance = 10000.0
	var tid := app.game.economy.build("rapid", "0,0", 0)
	app.game.economy.upgrade(tid)
	app.game.economy.upgrade(tid)
	app.game.set_tower_tier_stat("rapid:frostneedle", "cost", 50.0)
	app.game.set_tower_tier_stat("rapid:thorn_volley", "cost", 150.0)
	app.game.data.balance = 100.0
	app.field.selected_tower = tid
	app.tower_actions.blocked = false
	app.tower_actions.refresh()
	if app.tower_actions.branch_bar.get_child(0).disabled or not app.tower_actions.branch_bar.get_child(1).disabled:
		failures.append("Branch buttons do not use independent affordability")
	app.game.data.balance = 200.0
	app.tower_actions.choose_branch(1)
	if app.tower_actions.pending_cost != 150.0 or app.tower_actions.chosen_branch != "thorn_volley":
		failures.append("Right branch quote does not retain its custom price")
	app.tower_actions.choose_branch(1)
	if app.game.data.towers[tid].level != 4 or app.game.data.balance != 50.0:
		failures.append("Right branch confirmation did not charge its quoted price")
	for failure in failures:
		push_error(failure)
	print("DEVELOPER TIERS UI: all types, five tiers per tower, numeric inputs, save/reload, responsive layout; failures: ", failures.size())
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
