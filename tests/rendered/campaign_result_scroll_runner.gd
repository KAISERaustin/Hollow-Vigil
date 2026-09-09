extends "res://tests/rendered/mobile_navigation_runner.gd"
## Return directly from a result dialog, then send real viewport touch gestures.

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://result-scroll-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	app.slot_menu.campaign_slots.base_path = app.game.save_path + "-slots"
	var saved: Dictionary = app.slot_menu.campaign_slots.create(0, "survival", "Scroll test")
	app.open_campaign_slot(0, saved)
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.progress.path = app.game.save_path + "-campaign"
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for result in ["victory", "defeat"]:
			campaign.start_mission(0)
			await settle()
			if result == "victory":
				campaign.run.wave = campaign.run.mission.waves.size() - 1
				campaign.run.start_wave()
				campaign.run.next_spawn = campaign.run.schedule.size()
				campaign.run.tick(0.01)
				check(campaign.reward_transition.active, "Final wave presents reward")
				await touch(Vector2(180, 300), true)
				await touch(Vector2(180, 300), false)
			else:
				campaign.run.health = 0
				campaign.run.start_wave()
				campaign.run.tick(0.01)
			await settle()
			var action: Button = campaign.dialog_body.get_child(-1)
			check(action.text == "World map", "Result exposes World map")
			await touch(action.get_global_rect().get_center(), true)
			await touch(action.get_global_rect().get_center(), false)
			await settle()
			check(campaign.page == "map" and not campaign.dialog.visible, "First result action returns to map")
			await swipe(campaign.page_scroll.get_global_rect().get_center())
			check(campaign.page_scroll.scroll_vertical > 30 and campaign.page == "map", "Immediate map swipe after %s at %s" % [result, dimensions])
			if DisplayServer.get_name() != "headless":
				await Harness.capture(app, "campaign-result-scroll-%s-%d" % [result, dimensions.x])
	app.queue_free()
	await settle()
	print("CAMPAIGN RESULT SCROLL: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
