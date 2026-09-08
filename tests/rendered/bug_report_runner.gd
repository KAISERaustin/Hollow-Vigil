extends "res://tests/rendered/unified_menu_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://bug-report-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	var mock := preload("res://tests/bug_reports_runner.gd").Network.new()
	root.add_child(mock)
	app.bug_reports.cloud = mock
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.show_main_menu()
		await press("MainSettings")
		check(button("SettingsBugReport") != null, "Main menu Settings includes Bug report")
		await press("SettingsBugReport")
		check(menu.screen == "bug_report", "Bug report opens")
		await press("UploadBugReport")
		check(mock.calls.is_empty(), "Blank form blocked")
		fill("BugReportTitle", "Tower selection report")
		var description: TextEdit = menu.find_child("BugReportDescription", true, false)
		description.text = "I tapped a tower after opening the map.\nExpected: the tower details should open."
		description.text_changed.emit()
		await capture("bug-report-form")
		await press("BackButton")
		await press("SettingsSound")
		await press("BackButton")
		check(button("SettingsBugReport") != null, "Settings origin survives submenu returns")
		await press("SettingsBugReport")
		check(menu.find_child("BugReportTitle", true, false).text == "Tower selection report", "Back navigation preserves draft")
		await press("UploadBugReport")
		check(app.bug_reports.status.begins_with("Couldn't upload"), "Offline result shown")
		await capture("bug-report-offline")
		mock.response = {"ok": true, "code": 201, "data": null}
		await press("UploadBugReport")
		check(app.bug_reports.status.begins_with("Bug report uploaded"), "Success shown")
		check(menu.find_child("BugReportTitle", true, false).text.is_empty(), "Successful form clears")
		await capture("bug-report-success")
		for type in ["campaign", "infinite"]:
			menu.show_home(type)
			await press("Settings")
			check(button("SettingsBugReport") == null, "Mode Settings excludes Bug report")
			menu.show_bug_report()
			check(menu.screen == "settings", "Direct entry outside main Settings blocked")
		menu.show_settings(menu.open_game_menu)
		check(button("SettingsBugReport") == null, "In-game Settings excludes Bug report")
		mock.calls.clear()
		mock.response = {"ok": false, "code": 0, "data": null}
	if "--live" in OS.get_cmdline_user_args():
		app.bug_reports.cloud = app.cloud
		menu.show_main_menu()
		await press("MainSettings")
		await press("SettingsBugReport")
		fill("BugReportTitle", "QA 1.1.1 native Godot form upload")
		var live_description: TextEdit = menu.find_child("BugReportDescription", true, false)
		live_description.text = "Release verification from the actual rendered main-menu bug report form. Title and description submitted using the production Godot HTTP service."
		live_description.text_changed.emit()
		await press("UploadBugReport")
		while app.bug_reports.busy: await process_frame
		check(app.bug_reports.status.begins_with("Bug report uploaded"), "Live native form upload confirmed")
		await capture("bug-report-live")
	app.queue_free()
	mock.queue_free()
	await frames()
	print("Bug report UI: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
