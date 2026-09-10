extends "res://tests/test_runner.gd"

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.slot_menu.campaign_slots.base_path = "res://.runtime/rules-navigation-" + str(Time.get_ticks_usec())
	var slot: Dictionary = app.slot_menu.campaign_slots.create(0, "creative", "Rules navigation")
	app.open_campaign_slot(0, slot)
	app.campaign.set_process(false)
	app.campaign.start_mission(0)
	var menu = app.slot_menu
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.show_campaign_content_rules()
		var browser = menu.rules_editor
		for category in ["enemies", "bosses", "towers"]:
			browser.category = category
			var items: Dictionary = Balance.TOWERS if category == "towers" else browser.editor_definitions()
			for kind in items:
				browser.open_item(category, kind)
				check(browser.item_menu.find_child("StatsMenu", true, false) != null, "Stats available for " + kind)
				check(browser.item_menu.find_child("AbilitiesMenu", true, false) == null and browser.item_menu.find_child("AttributesMenu", true, false) == null, "Capabilities absent for " + kind)
				browser.cancel_item()
		browser.show_categories()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/simplified-categories-%d.png" % dimensions.x)
		check(not browser.categories.has("rifts"), "No portals in Edit rules")
		check(browser.tabs.gear.disabled, "Gear button is disabled")
		for category in ["enemies", "bosses", "towers"]:
			browser.show_category(category)
			for frame in range(6): await process_frame
			menu.fit()
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/rules-%d-%s-list.png" % [dimensions.x, category])
			check(browser.listing.visible and not browser.editor.visible, category + " opens list")
			var definitions: Dictionary = Balance.TOWERS if category == "towers" else browser.editor_definitions()
			check(browser.listing.get_child_count() == definitions.size(), category + " lists all items")
			browser.open_item(category, definitions.keys()[0])
			check(browser.item_menu.visible and not browser.editor.visible, category + " opens item menu")
			check(browser.item_menu.find_child("AbilitiesMenu", true, false) == null and browser.item_menu.find_child("AttributesMenu", true, false) == null, "No capability menu buttons")
			for group in ["Stats"]:
				browser.open_group(group)
				check(browser.editor.visible and not browser.item_menu.visible, category + " separate " + group)
				if browser.stats_editor != null:
					check(browser.stats_editor.group == group and not browser.stats_editor.get_child(0).visible, "Only selected group")
				for frame in range(6): await process_frame
				menu.fit()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/rules-%d-%s-%s.png" % [dimensions.x, category, group])
				browser.navigate_back()
			browser.cancel_item()
		browser.open_item("enemies", "basic")
		var original: Dictionary = browser.game.tuning.duplicate(true)
		browser.open_group("Stats")
		var hp = browser.find_child("hpValue", true, false)
		hp.value += 10
		browser.cancel_item()
		check(browser.game.tuning == original and menu.campaign_rule_changes.is_empty(), "Cancel restores draft and pending edits")
		browser.hide()
		menu.level_rules.show_levels()
		for index in menu.level_rules.Configuration.Catalog.COUNT:
			menu.level_rules.show_level(index)
			check(menu.level_rules.get_child_count() == 2 and menu.level_rules.get_child(1).text == "Stats", "Level has only title and Stats")
			if index == 0:
				for frame in range(6): await process_frame
				menu.fit()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/rules-%d-level.png" % dimensions.x)
			menu.level_rules.open_group("Stats")
			check(menu.level_rules.numbers.size() == 2, "Level stats only starting gold and lives")
			check(menu.level_rules.find_child("LevelRule_reward", true, false) == null, "Wave reward is not editable in level stats")
			if index == 0:
				for frame in range(6): await process_frame
				menu.fit()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/rules-%d-level-stats.png" % dimensions.x)
			menu.level_rules.navigate_back()
			menu.level_rules.cancel_item()
		check(not menu.has_rule_changes(), "Browsing and cancelling items leaves rules unchanged")
		browser.show()
		menu.level_rules.hide()
		browser.open_item("enemies", "basic")
		browser.open_group("Stats")
		hp = browser.find_child("hpValue", true, false)
		var saved_hp: float = hp.value
		await process_frame
		hp.value += 10
		await process_frame
		browser.save_item()
		check(menu.has_rule_changes(), "Saved item edit requires discard confirmation")
		browser.open_item("enemies", "basic")
		browser.open_group("Stats")
		hp = browser.find_child("hpValue", true, false)
		await process_frame
		hp.value = saved_hp
		await process_frame
		browser.save_item()
		check(not menu.has_rule_changes(), "Restoring original content value clears changes")
		menu.level_rules.show_level(0)
		menu.level_rules.open_group("Stats")
		var gold: SpinBox = menu.level_rules.numbers[0]
		await process_frame
		var saved_gold := gold.value
		gold.value += 10
		check(menu.has_rule_changes(), "Level edit requires discard confirmation")
		gold.value = saved_gold
		await process_frame
		menu.level_rules.show_levels()
		check(not menu.has_rule_changes(), "Restoring original level value clears changes")
		menu.level_rules.hide()
		browser.show_categories()
		var exits := [0]
		menu.rules_return = func(): exits[0] += 1
		var child_count: int = menu.get_child_count()
		menu.rules_back()
		check(exits[0] == 1 and menu.get_child_count() == child_count, "Unchanged Back exits without dialog")
		menu.cancel_rules()
		check(exits[0] == 2 and menu.get_child_count() == child_count, "Unchanged Cancel exits without dialog")
		menu.level_rules.changes = {"0": {"gold": saved_gold + 10}}
		menu.cancel_rules()
		check(exits[0] == 2 and menu.get_child_count() == child_count + 1, "Unsaved changes still show confirmation")
		menu.get_child(menu.get_child_count() - 1).queue_free()
		await process_frame
	menu.hide()
	var tower := Balance.Content.tower("rapid").create("1", "0,0", 0)
	app.campaign.game.data.towers["1"] = tower
	app.campaign.field.selected_tower = "1"
	app.campaign.tower_dialog.open_action("info")
	var gear: Button = app.campaign.tower_dialog.find_child("Manage_equipment", true, false)
	check(gear != null and gear.disabled, "Tower gear button stays visible and disabled")
	app.campaign.tower_dialog.open_action("equipment")
	check(app.campaign.tower_dialog.mode == "info", "Gear navigation cannot open")
	app.queue_free()
	await process_frame
	print("RULES NAVIGATION: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
