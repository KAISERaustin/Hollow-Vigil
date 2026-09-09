extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func settle() -> void:
	for i in 10: await process_frame
	await create_timer(0.2).timeout

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
	check(build.visible and build.palette.visible, label + " persistent cards")
	check(is_equal_approx(build.palette.size.x, host.size.x), label + " drawer spans full width")
	check(is_equal_approx(build.palette.position.y + build.palette.size.y, host.size.y), label + " drawer touches bottom edge")
	check(build.palette.get_child(0).get_child_count() == 1, label + " drawer contains only tower row")
	var strip: ScrollContainer = build.palette.find_child("TowerCards", true, false)
	for card in strip.get_node("Cards").get_children():
		check(card.size.y >= 48, label + " tower touch height " + card.name)
		check(strip.get_global_rect().grow(1).encloses(card.get_global_rect()), label + " entire card reachable " + card.name)
	strip.scroll_horizontal = 0
	await settle()
	check(is_equal_approx(strip.global_position.x, 8) and is_equal_approx(strip.size.x, host.size.x - 16), label + " matching outer gutters")
	var first_card: Control = strip.find_child("Build_rapid", true, false)
	check(is_equal_approx(first_card.global_position.x, 8), label + " left gutter matches card spacing")
	var last_card: Control = strip.get_node("Cards").get_child(-1)
	check(strip.scroll_horizontal == 0, label + " complete catalog visible without scrolling")
	check(is_equal_approx(host.size.x - last_card.get_global_rect().end.x, 8), label + " right gutter matches card spacing")
	strip.scroll_horizontal = 0
	await settle()
	check(is_equal_approx(first_card.global_position.y, build.palette.global_position.y), label + " no outer top padding")
	var outside := Vector2(host.size.x * 0.5, build.palette.position.y - 20)
	await touch(outside, true)
	await touch(outside, false)
	await settle()
	check(build.visible and build.palette.visible, label + " outside tap retains cards")
	check(build.palette.get_global_rect().grow(1).encloses(build.palette.find_child("TowerCards", true, false).get_global_rect()), label + " cards fit")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ground-palette-%s-%d.png" % [label, root.size.x])
	# Capture composite bow artwork at a nonzero position and both raster/native zooms.
	var previous_zoom := field.zoom
	for preview_zoom in [1.0, 3.0]:
		field.zoom = preview_zoom
		build.arm("ironspike")
		await settle()
		await touch(build.banner.find_child("BuildPortrait", true, false).get_global_rect().get_center(), true)
		await drag(field.global_position + field.size * 0.5)
		check(build.dragging and build.kind == "ironspike", label + " Ironspike drag renders composite artwork")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/ground-ironspike-%s-%d-%d.png" % [label, root.size.x, preview_zoom])
		build.cancel()
	field.zoom = previous_zoom
	var button: Button = build.palette.find_child("Build_rapid", true, false)
	var start := button.get_global_rect().get_center()
	var before: int = host.game.data.towers.size()
	var funds: float = host.game.data.balance
	await touch(start, true)
	await touch(start, false)
	await settle()
	check(build.kind == "rapid" and not build.dragging and not build.valid, label + " tap shows information without placement")
	check(is_equal_approx(build.banner.global_position.x, strip.global_position.x) and is_equal_approx(build.banner.size.x, strip.size.x), label + " popup aligns with cards")
	check(is_equal_approx(build.palette.global_position.y - build.banner.get_global_rect().end.y, 12), label + " popup floats above cards")
	check(build.banner.find_children("*", "Button", true, false).is_empty(), label + " no cancel button")
	check(build.banner.find_child("BuildPortrait", true, false).size == Vector2(96, 96), label + " enlarged portrait")
	check(build.banner.get_global_rect().encloses(build.banner.find_child("LevelSquares", true, false).get_global_rect()), label + " level cubes fit popup")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ground-info-%s-%d.png" % [label, root.size.x])
	start = build.banner.find_child("BuildPortrait", true, false).get_global_rect().get_center()
	await touch(start, true)
	check(not build.dragging, label + " portrait press waits for drag")
	await drag(start - Vector2(0, 40))
	check(build.kind == "rapid" and build.dragging, label + " upward drag owns pointer")
	var blocked := field.global_position + field.screen(Vector2.ZERO)
	await drag(blocked)
	await touch(blocked, false)
	check(not build.kind.is_empty() and not build.valid, label + " invalid release retains preview")
	check(host.game.data.towers.size() == before and host.game.data.balance == funds, label + " invalid release spends nothing")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ground-blocked-%s-%d.png" % [label, root.size.x])
	await settle()
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
		await touch(target, true)
		await touch(target, false)
		check(host.game.data.towers.size() == before, label + " battlefield tap does not build")
		check(build.kind.is_empty() and not build.banner.visible, label + " outside tap dismisses preview")
		build.arm("rapid")
		await settle()
		await touch(build.banner.find_child("BuildPortrait", true, false).get_global_rect().get_center(), true)
		await drag(target)
		check(build.valid, label + " retry preview valid")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/ground-range-%s-%d.png" % [label, root.size.x])
		await touch(target, false)
		check(host.game.data.towers.size() == before + 1 and (build.kind.is_empty() and build.palette.visible), label + " retry release builds once")
		check(is_equal_approx(funds - host.game.data.balance, Balance.definition("towers", "rapid", host.game.tuning).cost), label + " spends exact price")
		field.tap(target - field.global_position)
		check(not field.selected_tower.is_empty(), label + " ground tower selectable")
		await settle()
		check(host.tower_dialog.visible and host.tower_dialog.mode == "info", label + " selected tower management open")
		var next_card: Button = build.palette.find_child("Build_ironspike", true, false)
		await touch(next_card.get_global_rect().get_center(), true)
		await drag(next_card.get_global_rect().get_center() - Vector2(0, 40))
		check(build.dragging and build.kind == "ironspike", label + " toolbar drag starts with management open")
		check(not host.tower_dialog.visible and field.selected_tower.is_empty(), label + " drag clears previous tower management")
		check(build.banner.visible, label + " dragged tower information visible")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/ground-switch-%s-%d.png" % [label, root.size.x])
		await drag(Vector2(-30, -30))
		await touch(Vector2(-30, -30), false)
	build.open()
	await settle()
	var scroll: ScrollContainer = build.palette.find_child("TowerCards", true, false)
	var swipe_start := scroll.global_position + Vector2(scroll.size.x - 30, 35)
	await touch(swipe_start, true)
	for step in range(1, 9):
		var swipe := InputEventScreenDrag.new()
		swipe.position = swipe_start - Vector2(step * 18, 0)
		swipe.relative = Vector2(-18, 0)
		Input.parse_input_event(swipe)
		await process_frame
	await touch(swipe_start - Vector2(144, 0), false)
	check(build.kind.is_empty(), label + " horizontal swipe does not arm a tower")
	if scroll.get_node("Cards").size.x > scroll.size.x:
		check(scroll.scroll_horizontal > 0, label + " horizontal finger swipe browses overflowing towers")
	else:
		check(scroll.scroll_horizontal == 0, label + " fitting row remains stationary")
	build.arm("rapid")
	await settle()
	blocked = field.global_position + Vector2(field.size.x * 0.5, 160)
	var count: int = host.game.data.towers.size()
	await touch(build.banner.find_child("BuildPortrait", true, false).get_global_rect().get_center(), true)
	await drag(blocked)
	await touch(blocked + Vector2(30, 0), true, 1)
	await touch(blocked + Vector2(30, 0), false, 1)
	check(build.dragging and build.pointer == 0 and host.game.data.towers.size() == count, label + " secondary finger cannot commit")
	await drag(Vector2(-30, -30))
	await touch(Vector2(-30, -30), false)
	check(not build.valid and host.game.data.towers.size() == count, label + " offscreen release cannot build")
	var dismiss_at := Vector2(host.size.x * 0.5, build.banner.position.y - 20)
	await touch(dismiss_at, true)
	await touch(dismiss_at, false)
	check((build.kind.is_empty() and build.palette.visible), label + " outside touch dismisses preview")
	build.open()
	build.arm("rapid")
	build._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check((build.kind.is_empty() and build.palette.visible) and host.game.data.towers.size() == count, label + " interruption cancels without spending")
	build.cancel()
	check(build.kind.is_empty() and (build.kind.is_empty() and build.palette.visible), label + " cancel clears preview")

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
	await settle()
	app.queue_free()
	await settle()
	print("GROUND BUILD TOUCH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
