extends "res://tests/test_runner.gd"

const Harness = preload("res://tests/rendered/visual_smoke.gd")

func settle() -> void:
	for index in range(8): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game = VigilState.new(879)
	app.game.save_path = "user://portal-roster-ui.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.field.set_process(false)
	app.field.set_unrestricted_camera(true)
	app.game.data.balance = 1000000.0
	app.game.expand("1,0")
	app.game.combat.enemies.clear()
	for size in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = size
		root.content_scale_size = size
		for style in VigilWorld.ALL_STYLES:
			var region: Dictionary = app.game.data.regions["1,0"]
			region.style = style
			region.unlocks = []
			region.traffic = 0
			app.game.terrain_revision += 1
			app.panels.close_sheet()
			app.field.camera = VigilWorld.center("1,0")
			app.field.zoom = 1.0
			app.field.queue_redraw()
			await settle()
			await Harness.tap(app, app.field.global_position + app.field.screen(VigilWorld.center("1,0")), size.x == 390)
			await settle()
			check(app.panels.mode == "rift" and app.panels.selection_region == "1,0", "Mouse/touch opens " + style + " portal at " + str(size))
			var rows := app.panels.find_children("PortalEnemy_*", "HBoxContainer", true, false)
			check(rows.size() == 3, "Portal shows exactly three inhabitants")
			for row in rows:
				app.panels.content_scroll.ensure_control_visible(row)
				await settle()
				check(app.panels.content_scroll.get_global_rect().grow(1).encloses(row.get_global_rect()), "Roster row is readable without horizontal clipping")
			for kind in Balance.portal_unlock_costs(style):
				var button := app.panels.find_child("Attune_" + kind, true, false) as Button
				app.panels.content_scroll.ensure_control_visible(button)
				await settle()
				check(app.panels.content_scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Attunement control is reachable")
				var before: float = app.game.data.balance
				await Harness.tap(app, button.get_global_rect().get_center(), size.x == 390)
				await settle()
				check(kind in region.unlocks and app.game.data.balance == before - Balance.portal_unlock_costs(style)[kind], "Visible attunement purchases exactly its own enemy")
			var traffic := app.panels.find_child("PortalTraffic", true, false) as Button
			app.panels.content_scroll.ensure_control_visible(traffic)
			await settle()
			await Harness.tap(app, traffic.get_global_rect().get_center(), size.x == 390)
			await settle()
			check(region.traffic == 1, "Visible portal traffic control works")
			app.panels.content_scroll.scroll_vertical = 0
			await settle()
			await Harness.capture(app, "portal-" + style + "-" + str(size.x))
	clean_test_save(app.game.save_path)
	app.queue_free()
	await process_frame
	print("PORTAL_UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
