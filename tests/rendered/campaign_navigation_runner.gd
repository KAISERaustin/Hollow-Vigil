extends "res://tests/rendered/mobile_campaign_controls_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-navigation-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.audio.set_suspended(true)
	check(app.show_save_slots(), "Open isolated slots")
	app.slot_menu.campaign_slots.base_path = app.game.save_path + ".campaign"
	for mode in ["creative", "survival"]:
		for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			var saved: Dictionary = app.slot_menu.campaign_slots.create(0, mode, "Navigation")
			app.open_campaign_slot(0, saved)
			campaign = app.campaign
			campaign.set_process(false)
			await press(named("CampaignLevel1"))
			check(campaign.page == "briefing", "Map opens information")
			await press(named("BeginCampaignMission"))
			check(campaign.page == "battle", "Begin enters battlefield")
			check(campaign.run.build(0, "rapid"), "Build progress before leaving")
			await press(named("StartCampaignWave"))
			var checkpoint: Dictionary = campaign.run.checkpoint()
			await press(named("GameMenuButton"))
			check(campaign.page == "briefing", "Toolbar Back opens information")
			check(named("BeginCampaignMission").text == "Resume level", "Information offers resume")
			await capture("navigation-information-" + mode)
			await press(named("BeginCampaignMission"))
			check(campaign.page == "battle" and campaign.paused, "Resume restores paused battle")
			check(campaign.run.checkpoint() == checkpoint, "Resume preserves tower and wave")
			await back()
			check(campaign.page == "briefing", "System Back opens information")
			await back()
			check(campaign.page == "map", "Information Back opens map")
			await press(named("CampaignLevel1"))
			check(campaign.page == "briefing", "Reopening level never skips information")
			await press(named("BeginCampaignMission"))
			check(campaign.run.checkpoint() == checkpoint, "Map round trip preserves progress")
			campaign.close()
			await settle()
	print("CAMPAIGN_NAVIGATION: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
