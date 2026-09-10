extends "res://tests/test_runner.gd"

func run() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	var app := VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.slot_menu.campaign_slots.base_path = "res://.runtime/rules-back-" + str(Time.get_ticks_usec())
	var slot: Dictionary = app.slot_menu.campaign_slots.create(0, "creative", "Back navigation")
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
			browser.show_category(category)
			var definitions: Dictionary = Balance.TOWERS if category == "towers" else browser.editor_definitions()
			for kind in definitions:
				browser.open_item(category, kind)
				for group in ["Stats"]:
					browser.item_menu.get_node(group + "Menu").pressed.emit()
					var context: String = category + "/" + kind + "/" + group
					check(browser.route == group, context + " group opens")
					if is_instance_valid(browser.stats_editor):
						var editor = browser.stats_editor
						var add_name: String = {"Stats":"AddStat", "Abilities":"AddAbility", "Attributes":"AddAttribute"}[group]
						for back_kind in ["inline", "header", "system"]:
							editor.find_child(add_name, true, false).pressed.emit()
							check(editor.choosing, context + " Add opens")
							if back_kind == "inline": editor.body.get_child(0).pressed.emit()
							elif back_kind == "header": menu.header.get_node("BackButton").pressed.emit()
							else: menu.go_back()
							check(not editor.choosing and browser.route == group and browser.editor.visible and not browser.item_menu.visible, context + " " + back_kind + " returns to group")
							check(browser.selected_kind == kind and editor.group == group, context + " preserves selection")
							for frame in range(3): await process_frame
					menu.header.get_node("BackButton").pressed.emit()
					check(browser.route == "item" and browser.item_menu.visible, context + " group Back returns to item")
					for frame in range(3): await process_frame
				menu.go_back()
				check(browser.route == "list", category + "/" + kind + " item Back returns to list")
				for frame in range(3): await process_frame
		browser.hide()
		menu.level_rules.show_levels()
		for index in menu.level_rules.Configuration.Catalog.COUNT:
			menu.level_rules.show_level(index)
			menu.level_rules.get_child(1).pressed.emit()
			check(menu.level_rules.group == "Stats", "Level Stats opens")
			menu.header.get_node("BackButton").pressed.emit()
			check(menu.level_rules.group.is_empty() and menu.level_rules.selected == index, "Level Stats Back returns to same level")
			for frame in range(3): await process_frame
			menu.go_back()
			check(menu.level_rules.selected == -1, "Level Back returns to levels")
			for frame in range(3): await process_frame
	app.queue_free()
	for frame in range(3): await process_frame
	print("RULES BACK: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
