extends "res://tests/rendered/campaign_runner.gd"
const Configuration = preload("res://scripts/campaign/configuration.gd")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-config-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	check(screen.select_campaign("creative", ""), "Campaign authoring selects Creative")
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
		var spawn_picker = editor.find_child("CampaignGroupKind0", true, false)
		check(spawn_picker.get_script() == preload("res://scripts/ui/shared/illustrated_picker.gd"), "Wave groups use illustrated selection")
		spawn_picker.show_popup()
		for settle in range(8): await frame()
		check(spawn_picker.rows.get_child_count() == Configuration.spawn_kinds().size(), "Every spawn type has an illustrated row")
		var action_x := -1.0
		for row in spawn_picker.rows.get_children():
			check(row.get_child_count() == 3 and row.get_child(0).custom_minimum_size == Vector2(64, 64), "Spawn choices have native portraits, titles and buttons")
			var action := row.get_child(2) as Button
			if action_x < 0: action_x = action.position.x
			check(is_equal_approx(action.position.x, action_x), "Spawn selection columns stay aligned")
		check(spawn_picker.popup.size.x <= dimensions.x and spawn_picker.popup.size.y <= dimensions.y, "Spawn picker fits phone")
		await Harness.capture(app, "campaign-spawn-picker-" + str(dimensions.x))
		var boss_index: int = Configuration.spawn_kinds().find("warden")
		spawn_picker.choose(boss_index)
		check(editor.groups[0][0] == "warden", "Boss portrait selection updates the matching group")
		spawn_picker.choose(0)
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
		check(configured.waves["0"].groups[0][0] == Configuration.spawn_kinds()[0], "Illustrated enemy selection survives apply and save")
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
