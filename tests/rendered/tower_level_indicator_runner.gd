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
	var app := VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	app.game.data.first_property_required = false
	var id := app.game.economy.build("rapid", "0,0", 1)
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
		check(indicator.get_node("LevelSquares").texture == Indicator.IMAGES[level - 1], "Correct image state")
		indicator.free()
	app.free()
	print("TOWER LEVEL INDICATOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
