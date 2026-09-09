extends "res://tests/rendered/mobile_navigation_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://equipment-scroll-" + str(Time.get_ticks_usec())
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.progress.path = app.game.save_path + "-campaign"
	campaign.start_mission(0)
	var socket: int = campaign.run.mission.sockets[0].index
	campaign.run.build(socket, "rapid")
	campaign.field.selected_tower = campaign.run.tower_at(socket)
	var relics = preload("res://scripts/gameplay/progression/relics.gd")
	var index := 0
	for kind in relics.DEFINITIONS:
		relics.award(campaign.game.data, "%d,90" % (90 + index), kind)
		index += 1
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		campaign.tower_dialog.open_action("info")
		await settle()
		campaign.tower_dialog.open_action("equipment")
		await settle()
		var dialog: VigilTowerDialog = campaign.tower_dialog
		print("GEOMETRY ", dimensions, " ", dialog.scroll.size, " range ", dialog.scroll.get_v_scroll_bar().max_value, " filter ", dialog.body.mouse_filter)
		await swipe(dialog.scroll.get_global_rect().get_center(), Vector2(0, -60))
		check(dialog.scroll.scroll_vertical > 20, "Inventory swipe moves rows at " + str(dimensions))
		check(dialog.mode == "equipment", "Swipe does not select equipment")
		if DisplayServer.get_name() != "headless":
			await Harness.capture(app, "equipment-scroll-%d" % dimensions.x)
	app.queue_free()
	await settle()
	print("EQUIPMENT SCROLL: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
