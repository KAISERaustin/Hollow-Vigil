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
			var defaults := fields.find_child("DefaultRules", true, false)
			var additions := fields.find_child("AddedRules", true, false)
			check(defaults != null and (additions != null) == (category == "towers"), "Current stat cards " + category)
			check(defaults.find_child("payoutValue", true, false) != null if category != "towers" else true, "Defeat gold belongs to defaults " + category)
			check(fields.find_child("DisableStat_payout", true, false) == null, "Cannot disable defeat gold " + category)
			check(fields.find_child("DisableStat_escape_damage", true, false) == null, "Cannot disable escape damage " + category)
			check(fields.find_child("DisableStat_splash", true, false) == null, "Cannot disable tower blast radius")
			for child: Control in fields.find_children("*", "Control", true, false):
				if child.is_visible_in_tree() and (child is Button or child is SpinBox):
					check(child.size.y >= 48, "Touch height " + category + "/" + child.name)
					check(child.get_global_rect().position.x >= menu.scroll.global_position.x - 1 and child.get_global_rect().end.x <= menu.scroll.get_global_rect().end.x + 1, "Horizontal fit " + category + "/" + child.name)
			await capture(category)
		for category in ["towers"]:
			menu.rules_editor.open_item(category, Balance.definitions(category).keys()[0])
			for group in ["Stats"]:
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
					if group == "Stats": check(not action.disabled, "Add Stat contains only missing stats")
					check(row.get_child(0).get_child_count() == 2, "Every choice has visible description")
					if row.get_child(0).get_child_count() == 2:
						check(row.get_child(0).get_child(1).text.length() > 30, "Detailed choice description")
					check(action.size.y >= 48 and row.get_global_rect().end.x <= menu.scroll.get_global_rect().end.x + 1, "Catalog mobile fit")
				await capture(category + "-" + group.to_lower() + "-choices")
				menu.rules_editor.navigate_back()
				check(menu.rules_editor.route == group and not editor.choosing and menu.rules_editor.editor.visible, "Back from catalog returns to selected group")
	app.queue_free()
	await process_frame
	print("STATS EDITOR: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

