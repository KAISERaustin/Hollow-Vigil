extends "res://tests/rendered/mobile_campaign_controls_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "res://artifacts/campaign-navigation-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.audio.set_suspended(true)
	app.slot_menu.show_slots()
	check(app.slot_menu.visible, "Open isolated Campaign slots")
	app.slot_menu.campaign_slots.base_path = app.game.save_path + ".campaign"
	for mode in ["creative", "survival"]:
		for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			app.slot_menu.campaign_slots.base_path = app.game.save_path + mode + str(dimensions.x)
			var saved: Dictionary = app.slot_menu.campaign_slots.create(0, mode, "Navigation")
			saved.completed = 1
			check(app.slot_menu.campaign_slots.save_slot(0, saved), "Seed previously completed level")
			app.open_campaign_slot(0, saved)
			campaign = app.campaign
			campaign.set_process(false)
			await press(named("CampaignLevel1"))
			check(campaign.page == "briefing", "Map opens information")
			await press(named("BeginCampaignMission"))
			check(campaign.page == "battle", "Begin enters battlefield")
			check(campaign.run.build(campaign.run.mission.sockets[0].index, "rapid"), "Build progress before leaving")
			await press(named("StartCampaignWave"))
			var checkpoint: Dictionary = campaign.run.checkpoint()
			await press(named("GameMenuButton"))
			check(campaign.page == "battle" and campaign.exit_confirmation, "Toolbar Back asks before discarding")
			campaign._process(0.1)
			check(campaign.run.checkpoint() == checkpoint, "Exit decision freezes the attempt")
			await capture("exit-confirmation-" + mode)
			await press(named("CancelCampaignExit"))
			check(campaign.page == "battle" and not campaign.exit_confirmation, "Cancel stays in level")
			check(campaign.run.checkpoint() == checkpoint, "Cancel preserves tower and wave")
			await back()
			check(campaign.exit_confirmation, "System Back asks before discarding")
			await back()
			check(not campaign.exit_confirmation and campaign.page == "battle", "System Back cancels confirmation")
			await press(named("GameMenuButton"))
			await press(named("ConfirmCampaignExit"))
			check(campaign.page == "briefing", "Exit opens information")
			check(campaign.campaign_save.checkpoint.is_empty(), "Exit clears saved checkpoint")
			var disk: Dictionary = app.slot_menu.campaign_slots.summary(0)
			check(disk.checkpoint.is_empty() and disk.completed == 1, "Disk clears attempt and preserves completion")
			check(named("BeginCampaignMission").text == "Begin level", "Information offers fresh start")
			campaign.close()
			await settle()
			app.open_campaign_slot(0, disk)
			campaign = app.campaign
			campaign.set_process(false)
			await press(named("CampaignLevel1"))
			check(named("BeginCampaignMission").text == "Begin level", "Reloaded slot cannot resume discarded attempt")
			await press(named("BeginCampaignMission"))
			check(campaign.run.game.data.towers.is_empty() and campaign.run.wave == 0 and campaign.run.phase == "planning", "Reentry resets towers and waves")
			check(campaign.run.game.data.balance == campaign.run.mission.gold and campaign.run.health == campaign.run.mission.flame, "Reentry resets gold and core")
			await back()
			await press(named("ConfirmCampaignExit"))
			await back()
			check(campaign.page == "map", "Information Back opens map")
			await press(named("CampaignLevel1"))
			check(campaign.page == "briefing", "Reopening level never skips information")
			await press(named("BeginCampaignMission"))
			check(campaign.run.game.data.towers.is_empty() and campaign.run.wave == 0, "Map round trip starts fresh")
			campaign.close()
			await settle()
	print("CAMPAIGN_NAVIGATION: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
