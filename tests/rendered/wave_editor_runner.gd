extends "res://tests/rendered/mobile_campaign_controls_runner.gd"
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Editor = preload("res://scripts/campaign/wave_editor.gd")

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://wave-edit-ui-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.open_campaign_slot(0, app.slot_menu.campaign_slots.create(0, "creative", "Wave editor test"))
	campaign = app.campaign
	campaign.set_process(false)
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = size
		root.content_scale_size = size
		campaign.start_mission(6)
		campaign.show_waves()
		await settle()
		var old_count: int = campaign.run.mission.waves.size()
		await press(named("NewCampaignWave"))
		check(campaign.dialog_title.text == "New wave", "New wave requires confirmation")
		await press(named("ConfirmNewWave"))
		check(campaign.run.mission.waves.size() == old_count + 1 and campaign.run.mission.waves[-1].is_empty(), "Confirmed new wave immediately saves empty")
		var saved: Dictionary = app.slot_menu.campaign_slots.summary(0)
		check(int(saved.levels["6"].overrides.wave_count) == old_count + 1, "New wave is persisted without Apply")
		await press(named("AddEnemiesWave%d" % (old_count + 1)))
		await settle()
		var picker = campaign.find_child("IllustratedSelectionMenu", true, false)
		check(picker != null and picker.visible, "Card Add enemies opens scrollable chooser")
		await press(named("Choice_23"))
		check(app.slot_menu.visible, "Choosing an enemy opens its wave setup")
		var editor = app.slot_menu.rules_editor
		check(editor.groups.size() == 1 and Balance.BOSSES.has(editor.groups[0][0]), "All-chapter boss can be added to an empty wave")
		var count: SpinBox = editor.find_child("CampaignGroup0_1", true, false)
		count.get_line_edit().text = "7"
		count.apply()
		check(campaign.run.mission.waves[-1][0][1] == 7, "Typed count saves immediately")
		await press(named("CampaignGroupPortal0"))
		await capture("portal-picker"); await press(named("Choice_1"))
		check(campaign.run.mission.waves[-1][0][2] == 1, "Portal choice saves immediately")
		var delay: SpinBox = editor.find_child("CampaignGroup0_3", true, false)
		delay.value = 2.5
		var spacing: SpinBox = editor.find_child("CampaignGroup0_4", true, false)
		spacing.value = 0.5
		var reward: SpinBox = editor.find_child("CampaignWaveReward", true, false)
		reward.value = 83
		var payout: SpinBox = editor.find_child("CampaignGroupGold0", true, false)
		payout.value = 11
		check(campaign.run.mission.wave_rules[-1].reward == 83 and campaign.run.mission.waves[-1][0][3] == 2.5, "Timing and wave gold save immediately")
		var report := Configuration.wave_report(campaign.run.mission, old_count)
		check(report.groups[0].gold_per_defeat == 11 and report.last_spawn_seconds == 5.5, "Simulation sees per-enemy gold and spacing")
		await audit(app.slot_menu.card, "Immediate wave editor")
		var scroll: ScrollContainer = app.slot_menu.scroll
		scroll.scroll_vertical = 0
		await capture("wave-editor")
		await press(named("DoneWaveRules"))
		check(campaign.waves_dialog and not app.slot_menu.visible, "Done returns to wave cards without Apply")
		var card: Control = campaign.find_child("WaveSummary%d" % (old_count + 1), true, false)
		await press(card.find_child("WaveEnemyCount_*", true, false))
		var quick: SpinBox = campaign.find_child("QuickWaveEnemyCount", true, false)
		check(quick.get_line_edit().virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER, "Quantity requests mobile number keypad")
		quick.get_line_edit().text = "0"
		quick.apply()
		await settle()
		check(campaign.run.mission.waves[-1].is_empty(), "Zero removes enemy from the card and saves")
		await press(named("RemoveWave%d" % (old_count + 1)))
		await press(named("ConfirmRemoveWave"))
		check(campaign.run.mission.waves.size() == old_count, "Removing custom wave restores correct count")
		await capture("editable-wave-cards")
		await press(named("EditCampaignWave1"))
		var reset_editor = app.slot_menu.rules_editor
		reset_editor.find_child("CampaignWaveReward", true, false).value = 321
		await press(named("ResetCampaignWave"))
		check(campaign.run.mission.wave_rules[0].reward == Configuration.Catalog.level(6).reward, "Reset wave immediately restores authored reward")
		await press(named("DoneWaveRules"))
		check(campaign.save_configuration(6, {"wave_count": 1, "waves": {"0": {"groups": [["basic", 1, 0, 0.0, 1.0]]}}}), "Minimal populated level saves")
		campaign.show_waves()
		await settle()
		await press(campaign.find_child("WaveEnemyCount_basic", true, false))
		var last_count: SpinBox = campaign.find_child("QuickWaveEnemyCount", true, false)
		last_count.value = 0
		await settle()
		check(last_count.value == 1 and campaign.run.mission.waves[0][0][1] == 1, "Removing the level's final enemy is rejected and restored")
		campaign.show_waves()
		await settle()
		await press(named("ResetLevelWaves"))
		await press(named("ConfirmResetWaves"))
		check(campaign.run.mission.waves.size() == old_count, "Reset all restores removed waves")
		campaign.run.start_wave()
		campaign.show_waves()
		await settle()
		check(named("NewCampaignWave") == null and named("EditCampaignWave1") == null and named("AddEnemiesWave1") == null, "All wave edits lock during active combat")
		campaign.mode = "survival"
		campaign.start_mission(6)
		campaign.show_waves()
		await settle()
		check(named("NewCampaignWave") == null and named("EditCampaignWave1") == null, "Survival cannot edit waves")
		campaign.mode = "creative"
	print("WAVE EDITOR TOUCH: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
