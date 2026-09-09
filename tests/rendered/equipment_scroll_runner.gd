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
		# Reproduce the mouse-first touch sequence used to dismiss a wave reward.
		campaign.reward_transition.play("Wave cleared", 20)
		campaign.reward_transition.set_process(false)
		var dismiss_event := InputEventMouseButton.new()
		dismiss_event.device = InputEvent.DEVICE_ID_EMULATION
		dismiss_event.button_index = MOUSE_BUTTON_LEFT
		dismiss_event.position = Vector2(dimensions) * 0.5
		dismiss_event.pressed = true
		Input.parse_input_event(dismiss_event)
		Input.flush_buffered_events()
		dismiss_event = dismiss_event.duplicate()
		dismiss_event.pressed = false
		Input.parse_input_event(dismiss_event)
		Input.flush_buffered_events()
		await settle()
		check(campaign.reward_transition.dismissed_pointers.is_empty(), "Wave reward releases inventory input")
		campaign.tower_dialog.open_action("info")
		await settle()
		campaign.tower_dialog.open_action("equipment")
		await settle()
		var dialog: VigilTowerDialog = campaign.tower_dialog
		dialog.scroll.scroll_vertical = 0
		await settle()
		var first: Button = dialog.body.find_child("Relic_90,90", true, false)
		await swipe(first.get_global_rect().get_center(), Vector2(0, -60))
		check(dialog.scroll.scroll_vertical > 20, "Swipe starting on equipment icon scrolls at " + str(dimensions))
		dialog.show_equipment_details("90,90")
		await settle()
		dialog.go_back()
		await settle()
		await swipe(dialog.scroll.get_global_rect().get_center(), Vector2(0, -60))
		check(dialog.scroll.scroll_vertical > 20, "Inventory swipe moves rows at " + str(dimensions))
		check(dialog.mode == "equipment", "Swipe does not select equipment")
		if DisplayServer.get_name() != "headless":
			await Harness.capture(app, "equipment-scroll-%d" % dimensions.x)
	app.queue_free()
	await settle()
	print("EQUIPMENT SCROLL: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
