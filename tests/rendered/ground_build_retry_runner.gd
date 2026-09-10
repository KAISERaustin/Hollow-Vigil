extends SceneTree

var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func touch(build: Control, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = pos
	event.pressed = pressed
	build._input(event)

func run() -> void:
	var host := VigilApp.new()
	host.load_saved_progress = false
	host.game.save_path = "user://build-retry.save"
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.open_campaign_slot(0, host.slot_menu.campaign_slots.create(0, "creative", "Retry test"))
	var app: Control = host.campaign
	app.start_mission(0)
	app.set_process(false)
	app.game.data.balance = 100000
	var build: Control = app.ground_build
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		build.arm("rapid")
		for i in 20: await process_frame
		build.dragging = true
		build.pointer = 0
		var blocked := Vector2(100, -20)
		touch(build, blocked, false)
		check(build.hovering and not build.dragging and not build.valid, "Invalid release retains preview")
		var retained: Vector2 = build.point
		touch(build, Vector2(100, 120), true)
		check(build.point == retained, "New press keeps preview until drag starts")
		var drag := InputEventScreenDrag.new()
		drag.position = Vector2(130, 140)
		build._input(drag)
		check(build.dragging and build.point != retained, "New gesture repositions tower")
		touch(build, blocked, false)
		check(build.hovering and build.kind == "rapid", "Repeated invalid drop remains adjustable")
		# Put the retained ghost inside the visible battlefield for rendered inspection.
		build.point = app.field.world(Vector2(150, 180) - app.field.global_position)
		build.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/build-retry-%d.png" % viewport.x)
		touch(build, Vector2(80, 100), true)
		touch(build, Vector2(80, 100), false)
		check(build.kind.is_empty() and not build.hovering, "Tap away dismisses retained preview")
		build.arm("rapid")
		build.dragging = true
		build.pointer = -1
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = blocked
		build._input(release)
		check(build.hovering, "Mouse invalid release retains preview")
		var destination := Vector2.ZERO
		for y in range(140, int(build.banner.position.y), 24):
			for x in range(30, viewport.x - 30, 24):
				build.point = app.field.world(Vector2(x, y) - app.field.global_position)
				build.refresh()
				if build.valid:
					destination = Vector2(x, y)
					break
			if destination != Vector2.ZERO: break
		check(destination != Vector2.ZERO, "Valid placement available")
		var count: int = app.game.data.towers.size()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = destination + Vector2(20, 0)
		build._input(press)
		var motion := InputEventMouseMotion.new()
		motion.position = destination
		build._input(motion)
		release.position = destination
		build._input(release)
		check(app.game.data.towers.size() == count + 1 and build.kind.is_empty(), "Mouse retry builds once on valid release")
	print("GROUND BUILD RETRY: %d failures" % failures)
	quit(1 if failures else 0)
