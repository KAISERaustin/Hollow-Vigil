extends SceneTree

const Indicator = preload("res://scripts/ui/shared/tower_level_indicator.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var host := VigilApp.new()
	host.load_saved_progress = false
	host.game.save_path = "user://tower-indicator-%d.save" % Time.get_ticks_usec()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.open_campaign_slot(0, host.slot_menu.campaign_slots.create(0, "creative", "Tower indicator test"))
	var app: Control = host.campaign
	app.start_mission(0)
	app.set_process(false)
	app.game.data.balance = 100000
	await settle()
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		for kind in Balance.TOWERS:
			app.ground_build.open()
			app.ground_build.arm(kind)
			await settle()
			var banner: Control = app.ground_build.banner
			var details: Control = banner.find_child("TowerDetails", true, false)
			check(details.size.y <= 144, "Compact construction row")
			check(banner.size.y < 210, "Placement panel stays compact")
			check(details.find_child("UpgradePaths", true, false) == null, "No premature specializations")
			var indicator: Control = details.find_child("TowerLevelIndicator", true, false)
			check(banner.get_global_rect().encloses(indicator.get_global_rect()), "Indicator fits panel")
			if kind == "rapid":
				root.get_texture().get_image().save_png("res://artifacts/compact-level-%d.png" % viewport.x)
		app.ground_build.cancel()
	var id: String = app.game.economy.build("rapid", app.run.mission.sockets[0].region, int(app.run.mission.sockets[0].pad))
	app.field.selected_tower = id
	for level in range(1, 5):
		app.game.data.towers[id].level = level
		app.game.data.towers[id].branch = "frostneedle" if level == 4 else ""
		app.tower_dialog.open_action("preview")
		await settle()
		check(app.tower_dialog.body.find_child("TowerLevelIndicator", true, false).get_meta("level") == level, "Placed tower shows owned level")
		check((app.tower_dialog.body.find_child("UpgradeBranches", true, false) != null) == (level == 3), "Only level three offers branches")
		app.tower_dialog.dismiss()
	for level in range(1, 5):
		var indicator := Indicator.create(level)
		app.add_child(indicator)
		await settle()
		check(indicator.get_meta("level") == level, "Correct owned level")
		var squares := indicator.get_node("LevelSquares")
		check(squares.get_child_count() == 4, "Four image squares")
		for index in 4:
			var artwork: TextureRect = squares.get_child(index)
			check(artwork.texture == Indicator.IMAGES[level - 1] and artwork.get_meta("earned") == (index < level), "Whole bubble image matches earned and empty state")
		indicator.free()
		var vertical_indicator := Indicator.create(level, false, true)
		app.add_child(vertical_indicator)
		await settle()
		var vertical_squares := vertical_indicator.get_node("LevelSquares")
		for position in 4:
			var bubble: TextureRect = vertical_squares.get_child(position)
			check(bubble.name == "Level%d" % (4 - position), "Vertical levels ordered four to one from top to bottom")
			check(bubble.get_meta("earned") == (4 - position <= level), "Earned vertical bubbles fill from the bottom upward")
		vertical_indicator.free()
	host.free()
	print("TOWER LEVEL INDICATOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
