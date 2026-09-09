extends "res://tests/test_runner.gd"

func settle() -> void:
	for frame in range(6): await process_frame

func press(parent: Node, name: String) -> void:
	var button := parent.find_child(name, true, false) as Button
	check(button != null, "Control exists: " + name)
	if button != null: button.pressed.emit()

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/stats-editor-%d-%s.png" % [root.size.x, label])

func run() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	var app := VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.slot_menu.campaign_slots.base_path = "res://.runtime/stats-ui-" + str(Time.get_ticks_usec())
	var slot: Dictionary = app.slot_menu.campaign_slots.create(0, "creative", "Stats test")
	app.open_campaign_slot(0, slot)
	app.campaign.set_process(false)
	app.campaign.start_mission(0)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var menu: Control = app.slot_menu
		menu.show_campaign_content_rules()
		menu.rules_editor.open_item("enemies", "basic")
		menu.rules_editor.open_group("Stats")
		await settle()
		check(menu.find_child("ApplyRules", true, false).text == "Save", "Explicit Save action")
		for category in ["enemies", "bosses", "towers"]:
			menu.rules_editor.open_item(category, Balance.definitions(category).keys()[0])
			menu.rules_editor.open_group("Stats")
			await settle()
			var fields: Control = menu.rules_editor.stats_editor
			check(fields != null, "Shared Stats editor for " + category)
			for child: Control in fields.find_children("*", "Control", true, false):
				if child.is_visible_in_tree() and (child is Button or child is SpinBox):
					check(child.size.y >= 48, "Touch height " + category + "/" + child.name)
					check(child.get_global_rect().position.x >= menu.scroll.global_position.x - 1 and child.get_global_rect().end.x <= menu.scroll.get_global_rect().end.x + 1, "Horizontal fit " + category + "/" + child.name)
			await capture(category)
		for category in ["enemies", "bosses", "towers"]:
			menu.rules_editor.open_item(category, Balance.definitions(category).keys()[0])
			for group in ["Stats", "Abilities", "Attributes"]:
				menu.rules_editor.open_group(group)
				var editor = menu.rules_editor.stats_editor
				editor.choosing = true
				editor.rebuild()
				await settle()
				for entry in editor.rows:
					var row: Control = entry.control
					var action := row.get_child(row.get_child_count() - 1) as Button
					check(row.get_meta("scroll_action_row", false), "Passive scroll row")
					check(action != null and action.text in ["Select", "Enabled"], "Separate selection action")
					check(row.get_child(0).get_child_count() == 2, "Every choice has visible description")
					if row.get_child(0).get_child_count() == 2:
						check(row.get_child(0).get_child(1).text.length() > 30, "Detailed choice description")
					check(action.size.y >= 48 and row.get_global_rect().end.x <= menu.scroll.get_global_rect().end.x + 1, "Catalog mobile fit")
				await capture(category + "-" + group.to_lower() + "-choices")
		menu.rules_editor.open_item("enemies", "basic")
		menu.rules_editor.open_group("Stats")
		menu.rules_editor.open_group("Attributes")
		press(menu, "AddAttribute")
		await capture("resistance-catalog")
		press(menu, "AddStat_poison_resistance")
		await settle()
		var number: SpinBox = menu.find_child("poison_resistanceValue", true, false)
		check(number != null, "Added resistance has value input")
		number.value = 65
		check(Balance.tuned_value("enemies", "basic", "poison_resistance", app.campaign.run.game.tuning) == 0, "Draft does not change live game")
		await capture("resistance-enabled")
		menu.rules_editor.open_group("Abilities")
		press(menu, "AddAbility")
		await capture("enemy-abilities")
		press(menu, "AddAbility_shield")
		press(menu, "ApplyRules")
		await settle()
		check(Balance.tuned_value("enemies", "basic", "poison_resistance", app.campaign.run.game.tuning) == 65, "Save reaches live game")
		for level in range(30):
			check(app.campaign.level_setup(level).overrides.tuning.enemies.basic.poison_resistance == 65, "Save reaches level " + str(level))
		menu.show_campaign_content_rules()
		menu.rules_editor.open_item("enemies", "basic")
		menu.rules_editor.open_group("Stats")
		press(menu, "ResetSelectedBalance")
		press(menu, "ApplyRules")
		check(Balance.tuned_value("enemies", "basic", "poison_resistance", app.campaign.run.game.tuning) == 0, "Reset removes added resistance")
		check(not Balance.Stats.ability_enabled("enemies", "basic", "shield", app.campaign.run.game.tuning), "Reset removes added ability")
		menu.show_campaign_content_rules()
		menu.rules_editor.open_item("towers", "rapid")
		menu.rules_editor.open_group("Stats")
		press(menu, "AddStat")
		await capture("stat-catalog")
		var search: LineEdit = menu.find_child("StatSearch", true, false)
		search.text = "slow strength"
		search.text_changed.emit(search.text)
		press(menu, "AddStat_slow_percent")
		check(Balance.Stats.ability_enabled("towers", "rapid", "frostneedle", menu.editor_game.tuning), "Adding dependent stat attaches its ability")
		press(menu, "CancelRules")
		await settle()
		check(menu.rules_editor.route == "list", "Cancel returns to item list")
		await settle()
		check(not Balance.Stats.ability_enabled("towers", "rapid", "frostneedle", app.campaign.run.game.tuning), "Cancel discards attachment draft")
	app.queue_free()
	await process_frame
	print("STATS EDITOR: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

