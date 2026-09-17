extends "res://tests/test_runner.gd"

func frame() -> void:
	for step in 4: await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://unlock-ui.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	for mode_index in 2:
		var mode: String = ["creative", "survival"][mode_index]
		var saved: Dictionary = app.slot_menu.campaign_slots.create(mode_index, mode, "Unlocks " + mode)
		app.open_campaign_slot(mode_index, saved)
		var campaign: Control = app.campaign
		campaign.set_process(false)
		for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			root.size = size
			root.content_scale_size = size
			campaign.progress.data.completed_levels = 0
			campaign.show_map()
			await frame()
			var map: Control = campaign.find_child("CampaignWorldMap", true, false)
			check(map.nodes.size() == 48, "All 48 levels rendered")
			for index in 48: check(map.nodes[index].disabled == (index > 0), "Only level one initially playable")
			campaign.start_mission(1)
			check(campaign.page == "map", "Direct launch cannot bypass the map lock")
			campaign.start_mission(0)
			await frame()
			for button in campaign.ground_build.palette.find_children("Build_*", "Button", true, false):
				check(button.disabled == (button.get_meta("tower_kind") != "rapid"), "Build palette preserves locks during refresh")
				var seal := button.get_node_or_null("LockedContentOverlay")
				check((seal != null) == (button.get_meta("tower_kind") != "rapid"), "Only progression-locked towers carry chains and padlock")
				if seal != null:
					check(seal.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Lock artwork never intercepts input")
					check(button.get_global_rect().encloses(seal.get_global_rect()), "Lock artwork fits its tower card")
			root.get_texture().get_image().save_png("res://artifacts/locked-towers-%s-%d.png" % [mode, size.x])
			check(campaign.run.build(6, "rapid"), "Starting tower builds")
			campaign.board.selected_tower = campaign.run.tower_at(6)
			campaign.tower_dialog.open_action("info")
			await frame()
			check(campaign.tower_dialog.confirm.disabled, "Tier two purchase locked in chapter one")
			check(campaign.tower_dialog.unlock_requirement.is_visible_in_tree() and campaign.tower_dialog.unlock_requirement.text.contains("chapter 2, level 1"), "Visible upgrade condition")
			check(Rect2(Vector2.ZERO, Vector2(size)).encloses(campaign.tower_dialog.card.get_global_rect()), "Locked tower panel fits portrait phone")
			root.get_texture().get_image().save_png("res://artifacts/unlocks-%s-%d.png" % [mode, size.x])
			campaign.tower_dialog.dismiss()
			campaign.progress.data.completed_levels = 8
			campaign.start_mission(0)
			await frame()
			check(campaign.run.build(6, "rapid") and campaign.run.upgrade(6), "Replay retains earned tier two upgrades")
			campaign.run = null
			campaign.show_map()
			await frame()
	app.queue_free()
	await process_frame
	print("Rendered campaign unlocks: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
