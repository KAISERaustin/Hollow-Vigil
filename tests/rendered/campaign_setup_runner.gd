extends "res://tests/rendered/campaign_runner.gd"
const Playthrough = preload("res://scripts/persistence/campaign_playthrough.gd")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-setup-ui-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.configuration_menu().slots.base_path = app.game.save_path + ".slots"
	app.slot_menu.hide()
	screen.set_process(false)
	check(screen.page == "setup" and screen.find_child("CampaignLevel1", true, false) == null, "Campaign opens setup before map")
	check(screen.find_child("ModeCreative", true, false) != null and screen.find_child("CampaignCommunity", true, false) != null, "Setup contains shared modes and community builds")
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = root.size
		screen.select_campaign("creative", "")
		for settle in 4: await frame()
		var open: Button = screen.find_child("OpenCampaignMap", true, false)
		screen.page_scroll.ensure_control_visible(open)
		await frame()
		check(screen.page_scroll.get_global_rect().grow(1).encloses(open.get_global_rect()), "Start reachable at " + str(dimensions))
		check(screen.layout.size.x <= screen.page_scroll.size.x + 1, "Setup fits phone width")
		await Harness.capture(app, "campaign-setup-" + str(dimensions.x))
		open.pressed.emit()
		check(screen.page == "map" and not screen.find_child("CampaignLevel20", true, false).disabled, "Creative can author every level")
		screen.start_mission(0)
		screen.run.start_wave()
		screen.run.tick(0.1)
		var live_enemy: Dictionary = screen.run.game.combat.enemies[0]
		var original_hp: float = live_enemy.hp
		screen.show_waves()
		screen.find_child("EditCampaignWave1", true, false).pressed.emit()
		await frame()
		var editor: Control = screen.find_child("CampaignBalancePanel", true, false)
		check(editor.live_run == screen.run and editor.scope == 0, "Wave preview opens current wave editor during play")
		editor.find_child("CampaignGroup0_1", true, false).get_line_edit().text = "12"
		editor.find_child("CampaignGroup0_4", true, false).get_line_edit().text = "0.5"
		editor.controls.show_category("enemies")
		editor.controls.inputs.hp.get_line_edit().text = "345"
		var save: Button = editor.find_child("SaveCampaignConfiguration", true, false)
		for settle in 4: await frame()
		screen.dialog_body.get_parent().ensure_control_visible(save)
		await frame()
		check(screen.dialog_card.get_global_rect().grow(1).encloses(save.get_global_rect()), "Live editor save reachable at " + str(dimensions))
		await Harness.capture(app, "campaign-live-editor-" + str(dimensions.x))
		save.pressed.emit()
		check(screen.run.schedule.size() == 11 and screen.run.game.tuning.enemies.basic.hp == 345, "Typed wave changes apply immediately")
		check(live_enemy.hp == original_hp, "Current enemy survives authoring unchanged")
		screen.close_dialog()
		screen.show_playthrough_share()
		check(app.slot_menu.export_campaign.levels.size() == 20, "Share includes every campaign level")
		app.slot_menu.find_child("SetupName", true, false).text = "Phone campaign " + str(dimensions.x)
		app.slot_menu.find_child("SaveLocalBuild", true, false).pressed.emit()
		check(app.slot_menu.message.text.contains("Saved on this device"), "Whole campaign saved with shared export UI")
		app.slot_menu.export_return.call()
		screen.show_setup()
		screen.select_campaign("survival", "")
		screen.show_playthrough_picker()
		await frame()
		var use: Button = app.slot_menu.find_child("UseCampaignBuild", true, false)
		check(use != null, "Saved campaign available in setup library")
		use.pressed.emit()
		await frame()
		check(screen.mode == "survival" and not screen.selected_build.is_empty(), "Survival loads chosen complete campaign")
		screen.show_map()
		screen.start_mission(0)
		screen.run.start_wave()
		check(screen.run.schedule.size() == 12 and screen.run.game.tuning.enemies.basic.hp == 345, "Survival replays saved wave rules from beginning")
		check(not screen.save_configuration(0, {"gold": 9999}) and not screen.run.apply_configuration({}), "Survival authoring locked at both owners")
		screen.show_waves()
		check(screen.find_child("EditCampaignWave1", true, false) == null, "Survival waves are read only")
		screen.close_dialog()
		screen.show_setup()
	check(app.campaign_progress.data.completed_levels == 0 and app.game.tuning.is_empty(), "Creative and custom builds leave original progress and Infinite untouched")
	var selected: String = screen.session.data.selections.survival
	screen.close()
	await process_frame
	app.show_campaign()
	check(app.campaign.page == "setup" and app.campaign.session.data.selections.survival == selected, "Reopening returns to setup with chosen campaign retained")
	app.queue_free()
	await process_frame
	print("CAMPAIGN SETUP UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
