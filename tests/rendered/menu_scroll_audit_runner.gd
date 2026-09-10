extends "res://tests/rendered/mobile_campaign_controls_runner.gd"
## Audit the shared full-page shell with actual touch drags after page rebuilds.

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://menu-scroll-audit-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.audio.set_suspended(true)
	var menu = app.slot_menu
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.begin_new(0)
		menu.new_game.mode = "creative"
		for route in ["show_main_menu", "show_home", "show_slots", "show_play_style", "show_starting_build", "show_review", "show_settings", "show_sound", "show_account", "show_backups"]:
			menu.call(route)
			await audit_page(route)
		menu.show_settings(menu.show_main_menu)
		menu.show_bug_report()
		await audit_page("bug_report")
		app.change_log.busy = true # Use local feed rows; do not request live data.
		app.change_log.entries.clear()
		for index in 20:
			app.change_log.entries.append({"change_date": "2026-09-09", "summary": "Scroll audit entry %d: verify wrapped release notes remain reachable." % index})
		menu.show_change_log()
		await audit_page("change_log")
		menu.open_library(false)
		await audit_page("my_builds")
		menu.open_build_form()
		await audit_page("save_build")
		# Revisit the same tall page: this caught the stale native range bug.
		menu.show_backups()
		await audit_page("backups_rebuilt")
	print("MENU SCROLL AUDIT: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func audit_page(context: String) -> void:
	await settle()
	var menu = app.slot_menu
	var scroll: ScrollContainer = menu.scroll
	var bar := scroll.get_v_scroll_bar()
	var overflow := maxf(0, bar.max_value - bar.page)
	check(scroll.size.y > 48, context + " has usable scroll viewport")
	await audit(menu.card, context)
	scroll.scroll_vertical = 0
	await settle()
	if overflow > 1:
		# Start in the content gutter so text editors retain text selection.
		var point := scroll.global_position + Vector2(2, scroll.size.y * 0.8)
		await swipe(point, Vector2(0, -minf(160, scroll.size.y * 0.6)))
		check(scroll.scroll_vertical > 0, context + " responds to a finger swipe")
		for attempt in 100:
			if scroll.scroll_vertical >= overflow - 2: break
			await swipe(point, Vector2(0, -minf(240, scroll.size.y * 0.6)))
		check(scroll.scroll_vertical >= overflow - 2, context + " finger swipes reach the bottom")
	await capture("scroll-" + context)
