extends "res://tests/rendered/mobile_campaign_controls_runner.gd"
## Shared wave playback through real toolbar taps and reward transitions.

func clear_wave() -> void:
	campaign.run.next_spawn = campaign.run.schedule.size()
	campaign.run.game.combat.enemies.clear()
	campaign.run.tick(Balance.STEP)
	campaign.reward_transition.set_process(false)

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://auto-wave-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.audio.set_suspended(true)
	app.slot_menu.campaign_slots.base_path = app.game.save_path + ".slots"
	var saved: Dictionary = app.slot_menu.campaign_slots.create(0, "creative", "Auto wave test")
	saved.completed = Catalog.COUNT
	app.open_campaign_slot(0, saved)
	campaign = app.campaign
	campaign.set_process(false)

	for index in Catalog.COUNT:
		var first := preload("res://scripts/campaign/run.gd").new(index)
		var second := preload("res://scripts/campaign/run.gd").new(index)
		first.auto_start_waves = true
		check(not second.auto_start_waves, "Level %d playback state is isolated" % index)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		campaign.start_mission(0)
		await settle()
		await audit(campaign.game_toolbar, "Auto-wave toolbar")
		check(campaign.wave_button.text.is_empty() and campaign.wave_button.accessibility_name.begins_with("Start wave"), "Play icon retains accessible Start wave name")
		check(is_equal_approx(campaign.wave_button.global_position.y, campaign.game_toolbar.menu_button.global_position.y), "Icon toolbar fits one row")
		check(campaign.auto_wave_button.global_position.x > campaign.wave_button.global_position.x and is_equal_approx(campaign.auto_wave_button.global_position.y, campaign.wave_button.global_position.y), "Skip stays right of Start wave")
		await press(campaign.auto_wave_button)
		check(campaign.run.auto_start_waves, "Touch enables auto waves")
		campaign._process(0.02)
		check(campaign.run.phase == "planning", "First wave still waits for Start wave")
		await capture("auto-wave-on")
		await press(campaign.wave_button)
		check(campaign.run.phase == "wave", "Manual Start wave remains functional")
		await clear_wave()
		check(campaign.reward_transition.active and campaign.run.phase == "planning", "Real wave clear shows reward")
		campaign._process(0.02)
		check(campaign.run.phase == "planning", "Auto start waits for reward")
		await tap_at(campaign.reward_transition.card.get_global_rect().get_center())
		check(not campaign.reward_transition.active, "Touch dismisses real reward")
		campaign.paused = true
		campaign._process(0.02)
		check(campaign.run.phase == "planning", "Pause blocks auto start")
		campaign.paused = false
		campaign.show_waves()
		campaign._process(0.02)
		check(campaign.run.phase == "planning", "Wave menu blocks auto start")
		campaign.close_dialog()
		campaign._process(0.02)
		check(campaign.run.phase == "wave" and campaign.run.wave == 1, "Next wave starts automatically after dismissal")
		await press(campaign.auto_wave_button)
		check(not campaign.run.auto_start_waves, "Touch disables auto waves during combat")
		await clear_wave()
		campaign.reward_transition.dismiss()
		campaign._process(0.02)
		check(campaign.run.phase == "planning", "Disabled auto waves waits for manual start")
		await capture("auto-wave-off")
		await press(campaign.wave_button)
		check(campaign.run.phase == "wave", "Manual start works after disabling")
		campaign.run.auto_start_waves = true
		campaign.run.wave = campaign.run.mission.waves.size() - 1
		await clear_wave()
		campaign.reward_transition.dismiss()
		campaign._process(0.02)
		check(campaign.run.phase == "victory", "Final wave never restarts")
	var prefix: String = app.game.save_path.get_file()
	app.queue_free()
	await process_frame
	await process_frame
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(prefix): DirAccess.remove_absolute("user://" + filename)
	print("AUTO WAVES: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
