extends "res://tests/rendered/unified_menu_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "res://artifacts/change-log-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	var mock := preload("res://tests/bug_reports_runner.gd").Network.new()
	root.add_child(mock)
	app.change_log.cloud = mock
	var sample: Array = []
	for i in 31:
		sample.append({"id": str(i), "change_date": "2026-09-08", "created_at": "2026-09-08T12:00:00Z", "summary": "Preview a tower's new attack range before upgrading."})
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.show_main_menu()
		await press("MainSettings")
		check(button("SettingsChangeLog").get_index() == button("SettingsBugReport").get_index() + 1, "Change log directly below Bug report")
		await capture("change-log-settings")
		mock.response = {"ok": true, "data": sample}
		await press("SettingsChangeLog")
		check(menu.screen == "change_log" and app.change_log.entries.size() == 30, "First page displays thirty entries")
		check(not mock.calls.back().authenticated, "Public reading needs no sign-in")
		await capture("change-log-rows")
		mock.response = {"ok": false}
		await press("ChangeLogMore")
		check(app.change_log.entries.size() == 30 and app.change_log.has_more, "Failed older page preserves entries and retry")
		mock.response = {"ok": true, "data": [sample.back()]}
		await press("ChangeLogMore")
		check(mock.calls.back().body.before_id == "29", "Paging uses last displayed entry")
		check(app.change_log.entries.size() == 31 and not app.change_log.has_more, "Older page appends and finishes")
		await press("ChangeLogRefresh")
		check(app.change_log.entries.size() == 1, "Refresh replaces entries")
		mock.response = {"ok": false}
		await press("ChangeLogRefresh")
		check(app.change_log.status.begins_with("Couldn't") and app.change_log.entries.size() == 1, "Offline refresh retains previous entries")
		await capture("change-log-offline")
		mock.response = {"ok": true, "data": []}
		await press("ChangeLogRefresh")
		check(app.change_log.entries.is_empty() and app.change_log.status == "No changes posted yet.", "Empty feed explained")
		await capture("change-log-empty")
		mock.response = {"ok": true, "data": [{"summary": 12}]}
		await press("ChangeLogRefresh")
		check(app.change_log.status.begins_with("Couldn't"), "Malformed response safely rejected")
		await press("BackButton")
		check(menu.screen == "settings", "Back returns to Settings")
		mock.response = {"ok": true, "data": sample}
		menu.show_change_log()
		check(app.change_log.busy and button("ChangeLogRefresh").disabled, "Loading blocks duplicate refresh")
		var calls_before: int = mock.calls.size()
		app.change_log.refresh()
		check(mock.calls.size() == calls_before, "Concurrent request ignored")
		menu.show_settings()
		await frames()
		check(menu.screen == "settings", "Late response cannot reopen dismissed feed")
		for mode in ["campaign", "infinite"]:
			menu.show_home(mode)
			await press("Settings")
			check(button("SettingsChangeLog") == null, "Entry scoped to main Settings")
	if "--live" in OS.get_cmdline_user_args():
		app.change_log.cloud = app.cloud
		menu.show_main_menu()
		await press("MainSettings")
		await press("SettingsChangeLog")
		while app.change_log.busy: await process_frame
		check(app.change_log.entries.size() == 30, "Live production first page")
		await press("ChangeLogMore")
		while app.change_log.busy: await process_frame
		check(app.change_log.entries.size() >= 46 and not app.change_log.has_more, "Live production full feed")
		menu.scroll.scroll_vertical = 0
		await capture("change-log-live")
	app.queue_free()
	mock.queue_free()
	await frames()
	print("Change log UI: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
