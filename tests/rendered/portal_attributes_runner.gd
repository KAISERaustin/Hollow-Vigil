extends "res://tests/test_runner.gd"

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.slot_menu.campaign_slots.base_path = "res://.runtime/portal-attributes-" + str(Time.get_ticks_usec())
	var slot: Dictionary = app.slot_menu.campaign_slots.create(0, "creative", "Portal attributes")
	app.open_campaign_slot(0, slot)
	app.campaign.set_process(false)
	var menu = app.slot_menu
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.show_campaign_content_rules()
		var browser = menu.rules_editor
		for style in Balance.portal_definitions():
			browser.open_item("rifts", style)
			var original: Dictionary = browser.game.tuning.duplicate(true)
			browser.open_group("Attributes")
			check(browser.inputs.has("armor_percent") and browser.inputs.has("health_regen_percent"), "Both attributes editable for " + style)
			browser.inputs.armor_percent.value = 25.0
			browser.inputs.health_regen_percent.value = 5.0
			check(browser.game.tuning.rifts[style].armor_percent == 25.0, "Armor updates draft")
			check(browser.game.tuning.rifts[style].health_regen_percent == 5.0, "Regeneration updates draft")
			for frame in range(6): await process_frame
			menu.fit()
			menu.scroll.scroll_vertical = 0
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			for number in browser.inputs.values():
				check(number.size.x > 0 and number.get_global_rect().end.x <= dimensions.x, "Fields fit portrait width")
			root.get_texture().get_image().save_png("res://artifacts/portal-attributes-%s-%d.png" % [style, dimensions.x])
			browser.cancel_item()
			check(browser.game.tuning == original, "Cancel restores portal rules")
	app.queue_free()
	await process_frame
	print("PORTAL ATTRIBUTE UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
