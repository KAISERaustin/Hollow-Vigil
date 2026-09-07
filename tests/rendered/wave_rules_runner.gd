extends "res://tests/rendered/unified_menu_runner.gd"

const Configuration = preload("res://scripts/campaign/configuration.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://wave-rules-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var slot := [360, 390, 540].find(dimensions.x)
		var saved: Dictionary = menu.campaign_slots.create(slot, "creative", "Wave edits")
		app.open_campaign_slot(slot, saved)
		var screen: Control = app.campaign
		screen.set_process(false)
		screen.show_briefing(7)
		await press("PreviewCampaignWaves")
		var original_second: Dictionary = Configuration.wave_report(screen.run.mission, 1)
		await press("EditCampaignWave1")
		check(menu.screen == "rules" and menu.rules_editor.scope == 0, "Wave 1 opens its rules draft")
		set_wave_fields(menu.rules_editor, 37, 103, 2.0, 0.5)
		await press("ApplyRules")
		check(not menu.visible and not menu.held and screen.dialog.visible and screen.waves_dialog, "Apply returns directly to Waves from briefing")
		check(screen.run.mission.waves[0][0][1] == 37, "Briefing mission uses the applied enemy count")
		check(screen.active_overrides == screen.level_setup(7).overrides, "Briefing tracks the applied rules")
		# Reopening must also be accurate even if the direct return assertion failed.
		screen.show_waves()
		await frames()
		check_wave_card(screen, 37, 103, 20.0)
		check(Configuration.wave_report(screen.run.mission, 1) == original_second, "Editing Wave 1 leaves Wave 2 unchanged")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/wave-rules-applied-%d.png" % dimensions.x)
		await press("WaveBalancingDetails1")
		var details := label_text(screen.dialog_body)
		check(details.contains("×37") and details.contains("Starts at 2 s") and details.contains("0.5 s\nSpawn interval"), "Balancing details use applied count and timing: " + details)
		screen.show_waves()
		await press("EditCampaignWave1")
		check(menu.rules_editor.find_child("CampaignGroup0_1", true, false).value == 37, "Reopened editor retains 37 enemies")
		menu.rules_editor.find_child("CampaignGroup0_1", true, false).get_line_edit().text = "99"
		await press("CancelRules")
		await press("ConfirmAction")
		check(not menu.visible and screen.waves_dialog and screen.dialog.visible, "Discard returns to Waves")
		check_wave_card(screen, 37, 103, 20.0)
		var stored: Dictionary = menu.campaign_slots.summary(slot)
		check(stored.levels["7"].overrides.waves["0"].groups[0][1] == 37, "Applied count persists in the saved Campaign")
		screen.close_dialog()
		await press("BeginCampaignMission")
		check(screen.run.mission.waves[0][0][1] == 37, "Beginning the level uses the previewed count")
		# Cover editing before a wave starts, then while an enemy is already alive.
		for active in [false, true]:
			if active:
				check(screen.run.start_wave(), "Start the edited wave")
				screen.run.tick(2.1)
			var held_run: RefCounted = screen.run
			var held_time: float = held_run.wave_time
			var enemies: Array = held_run.game.combat.enemies.duplicate(true)
			var count := 41 if active else 39
			screen.paused = active
			screen.show_waves()
			await press("EditCampaignWave1")
			set_wave_fields(menu.rules_editor, count, 109, 2.0, 0.5)
			await press("ApplyRules")
			check(not menu.visible and screen.dialog.visible and screen.waves_dialog, "Apply returns to Waves during battle")
			check(screen.run == held_run and held_run.wave_time == held_time and screen.paused == active, "Applying preserves the live run, time and prior pause state")
			check(held_run.game.combat.enemies == enemies, "Applying preserves already spawned enemies")
			check_wave_card(screen, count, 109, 2.0 + (count - 1) * 0.5)
			if active: check(held_run.schedule.size() + enemies.size() == count, "Pending spawns agree with the edited wave total")
		var before: Dictionary = screen.run.mission.duplicate(true)
		check(screen.save_configuration(8, {"gold": 777}), "Another level can save its own rules")
		check(screen.run.mission == before, "Editing another level leaves this live mission unchanged")
		screen.close()
		await frames()
	# The existing unslotted editor shares the same refresh and return behavior.
	app.show_campaign()
	var legacy: Control = app.campaign
	legacy.set_process(false)
	legacy.select_campaign("creative", "")
	legacy.show_briefing(7)
	legacy.show_waves()
	await press("EditCampaignWave1")
	var editor: Control = legacy.dialog_body.get_child(0)
	set_wave_fields(editor, 37, 103, 2.0, 0.5)
	editor.save_changes()
	await frames()
	check(legacy.dialog.visible and legacy.waves_dialog, "Unslotted wave save returns to Waves")
	legacy.show_waves()
	await frames()
	check_wave_card(legacy, 37, 103, 20.0)
	print("WAVE_RULES: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func set_wave_fields(editor: Control, count: int, reward: int, delay: float, interval: float) -> void:
	# Leave text uncommitted to exercise Apply's SpinBox commit path.
	editor.find_child("CampaignGroup0_1", true, false).get_line_edit().text = str(count)
	editor.find_child("CampaignWaveReward", true, false).get_line_edit().text = str(reward)
	editor.find_child("CampaignGroup0_3", true, false).get_line_edit().text = str(delay)
	editor.find_child("CampaignGroup0_4", true, false).get_line_edit().text = str(interval)

func check_wave_card(screen: Control, count: int, reward: int, last_spawn: float) -> void:
	var card: Control = screen.dialog_body.find_child("WaveSummary1", true, false)
	check(card != null, "Applied wave card is present")
	if card == null: return
	var stats: Control = card.find_child("WaveStats", true, false)
	var hp: float = Configuration.wave_report(screen.run.mission, 0).groups[0].spawn_health
	var expected := [str(count), str(reward), UI.exact_money(hp * count), "%s s" % UI.exact_money(last_spawn)]
	for index in expected.size():
		check(label_text(stats.get_child(index)).split("\n")[0] == expected[index], "Wave stat %d displays %s" % [index, expected[index]])
	check(label_text(card.find_child("EnemyRoster", true, false)).contains("×%d" % count), "Enemy roster displays the applied count")

func label_text(node: Node) -> String:
	var result: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false): result.append(label.text)
	return "\n".join(result)
