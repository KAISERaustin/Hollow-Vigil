extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func settle() -> void:
	for i in 10: await process_frame

func touch(at: Vector2, down: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = index
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func drag(at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = at
	event.index = 0
	event.relative = Vector2(0, -30)
	Input.parse_input_event(event)
	await process_frame

func exercise(host: Control, label: String) -> void:
	var build: Control = host.ground_build
	var field: Battlefield = host.field
	host.game.data.balance = 100000
	host.game.data.first_property_required = false
	build.open()
	await settle()
	check(build.palette.get_global_rect().grow(1).encloses(build.palette.find_child("TowerCards", true, false).get_global_rect()), label + " cards fit")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ground-palette-%s-%d.png" % [label, root.size.x])
	var button: Button = build.palette.find_child("Build_rapid", true, false)
	var start := button.get_global_rect().get_center()
	var before: int = host.game.data.towers.size()
	var funds: float = host.game.data.balance
	await touch(start, true)
	await drag(start - Vector2(0, 40))
	check(build.kind == "rapid" and build.dragging, label + " upward drag owns pointer")
	var blocked := field.global_position + field.screen(Vector2.ZERO)
	await drag(blocked)
	await touch(blocked, false)
	check(not build.kind.is_empty() and not build.valid, label + " invalid release retains preview")
	check(host.game.data.towers.size() == before and host.game.data.balance == funds, label + " invalid release spends nothing")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ground-blocked-%s-%d.png" % [label, root.size.x])
	var target := Vector2.INF
	for y in range(110, int(field.size.y) - 75, 10):
		for x in range(25, int(field.size.x) - 25, 10):
			var screen_point := Vector2(x, y)
			var location := VigilWorld.ground_location(field.world(screen_point))
			if host.game.economy.can_place("rapid", location.region, location.pad) and not build.banner.get_global_rect().has_point(field.global_position + screen_point):
				target = field.global_position + screen_point
				break
		if target.is_finite(): break
	check(target.is_finite(), label + " clear ground visible")
	if target.is_finite():
		await touch(blocked, true)
		await drag(target)
		check(build.valid, label + " retry preview valid")
		await touch(target, false)
		check(host.game.data.towers.size() == before + 1 and not build.visible, label + " retry release builds once")
		check(is_equal_approx(funds - host.game.data.balance, Balance.definition("towers", "rapid", host.game.tuning).cost), label + " spends exact price")
		field.tap(target - field.global_position)
		check(not field.selected_tower.is_empty(), label + " ground tower selectable")
	build.open()
	await settle()
	build.arm("rapid")
	build.cancel()
	check(build.kind.is_empty() and not build.visible, label + " cancel clears preview")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://ground-build-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await settle()
		await exercise(app, "infinite")
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.start_mission(0)
	campaign.set_process(false)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await settle()
		await exercise(campaign, "campaign")
	app.free()
	print("GROUND BUILD TOUCH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
