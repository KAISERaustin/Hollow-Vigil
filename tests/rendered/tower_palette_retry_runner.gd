extends "res://tests/rendered/mobile_navigation_runner.gd"

func settle() -> void:
	for frame in 12: await process_frame
	await create_timer(0.2).timeout

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://palette-retry-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.progress.path = app.game.save_path + "-campaign"
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		campaign.start_mission(0)
		for attempt in 3:
			await settle()
			var build: Control = campaign.ground_build
			var strip: ScrollContainer = build.palette.find_child("TowerCards", true, false)
			campaign.game.data.balance = 100000
			await settle()
			for card in strip.get_node("Cards").get_children():
				check(strip.get_global_rect().grow(1).encloses(card.get_global_rect()), "Entire catalog fits %s attempt %d: %s" % [dimensions, attempt, card.name])
				check(card.size.y >= 48, "Card keeps touch height")
			check(strip.scroll_horizontal == 0, "No horizontal scrolling needed")
			var last: Button = strip.get_node("Cards").get_child(-1)
			await touch(last.get_global_rect().get_center(), true)
			await touch(last.get_global_rect().get_center(), false)
			await settle()
			check(build.kind == last.get_meta("tower_kind"), "Rightmost tower receives touch at %s attempt %d" % [dimensions, attempt])
			await Harness.capture(app, "tower-palette-retry-%d-%d" % [dimensions.x, attempt])
			build.cancel()
			# Exercise the iPhone ordering: the synthesized mouse press can arrive
			# first when dismissing a wave reward, before a later defeat/restart.
			campaign.run.start_wave()
			campaign.run.next_spawn = campaign.run.schedule.size()
			campaign.run.tick(0.01)
			check(campaign.reward_transition.active, "Wave clear presents reward")
			var dismiss := InputEventMouseButton.new()
			dismiss.device = InputEvent.DEVICE_ID_EMULATION
			dismiss.button_index = MOUSE_BUTTON_LEFT
			dismiss.position = campaign.size * 0.5
			dismiss.pressed = true
			Input.parse_input_event(dismiss)
			Input.flush_buffered_events()
			dismiss = dismiss.duplicate()
			dismiss.pressed = false
			Input.parse_input_event(dismiss)
			Input.flush_buffered_events()
			await settle()
			check(campaign.reward_transition.dismissed_pointers.is_empty(), "Reward releases touch ownership before defeat")
			campaign.run.health = 0
			campaign.run.start_wave()
			campaign.run.tick(0.01)
			await settle()
			var restart: Button = campaign.dialog_body.get_child(-2)
			check(restart.text == "Restart level", "Defeat offers restart")
			await touch(restart.get_global_rect().get_center(), true)
			await touch(restart.get_global_rect().get_center(), false)
			await settle()
			check(campaign.run.phase == "planning" and not campaign.dialog.visible, "Restart returns to planning at %s attempt %d" % [dimensions, attempt])
	app.queue_free()
	await settle()
	print("PALETTE RETRY: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
