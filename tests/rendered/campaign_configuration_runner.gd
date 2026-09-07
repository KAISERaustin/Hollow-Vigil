extends "res://tests/rendered/campaign_runner.gd"

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-config-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	var configuration_path: String = screen.configuration.path
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = root.size
		screen.show_balancing_levels()
		check(screen.dialog_body.get_child_count() == 20, "Every campaign level has balancing controls")
		screen.find_child("BalanceLevel7", true, false).pressed.emit()
		await frame()
		var editor: Control = screen.find_child("CampaignBalancePanel", true, false)
		check(editor.controls.get_script() == preload("res://scripts/ui/developer/developer_controls.gd"), "Campaign reuses the shared stat editor")
		check(not editor.controls.categories.has("session"), "Campaign uses its own level starting resources")
		editor.find_child("Campaign_gold", true, false).get_line_edit().text = "987"
		editor.controls.show_category("towers")
		editor.controls.inputs.damage.get_line_edit().text = "19"
		editor.scope_picker.select(1)
		editor.scope_picker.item_selected.emit(1)
		editor.find_child("CampaignGroup0_1", true, false).get_line_edit().text = "7"
		editor.find_child("CampaignGroup0_4", true, false).get_line_edit().text = "0.25"
		editor.controls.show_category("enemies")
		editor.controls.inputs.hp.get_line_edit().text = "321"
		var save: Button = editor.find_child("SaveCampaignConfiguration", true, false)
		for settle in range(4): await frame()
		screen.dialog_body.get_parent().ensure_control_visible(save)
		await frame()
		check(screen.dialog_card.get_global_rect().grow(1).encloses(save.get_global_rect()), "Save remains reachable at " + str(dimensions))
		await Harness.capture(app, "campaign-configuration-" + str(dimensions.x))
		save.pressed.emit()
		check(editor.message.text.begins_with("Level configuration saved"), "Save commits every typed field")
		var configured: Dictionary = screen.configuration.overrides(6)
		check(configured.gold == 987.0 and configured.tuning.towers.rapid.damage == 19.0, "Level values survive scope changes")
		check(configured.waves["0"].groups[0][1] == 7.0 and configured.waves["0"].groups[0][4] == 0.25 and configured.waves["0"].tuning.enemies.basic.hp == 321.0, "Wave controls and shared enemy stats persist together")
	screen.show_level_export(6)
	await frame()
	var code: String = screen.find_child("CampaignExportCode", true, false).text
	check(JSON.parse_string(JSON.parse_string(code).payload).level == 7, "Export UI contains only selected level")
	check(screen.find_child("CopyCampaignExport", true, false) != null, "Export has a copy action")
	screen.progress.data.completed_levels = 6
	screen.start_mission(6)
	check(screen.game.data.balance == 987.0, "Saved balancing is applied at mission start")
	screen.run.start_wave()
	check(screen.run.schedule.size() == 7 and screen.game.tuning.enemies.basic.hp == 321.0, "Saved wave balance reaches real campaign run")
	screen.show_waves()
	await frame()
	screen.show_wave_balance(1)
	await frame()
	check(screen.dialog_title.text == "Wave 2 balancing", "Per-wave balancing details are accessible")
	check(app.game.tuning.is_empty(), "Campaign authoring does not change Infinite Worlds")
	screen.close()
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(configuration_path + suffix)
	app.queue_free()
	await process_frame
	print("CAMPAIGN CONFIGURATION UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
