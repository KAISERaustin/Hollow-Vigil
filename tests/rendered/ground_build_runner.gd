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
	var strip: Control = build.palette.find_child("TowerCards", true, false)
	check(is_zero_approx(strip.global_position.x) and is_equal_approx(strip.size.x, host.size.x), label + " cards clip at screen edges")
	var first_card: Control = strip.find_child("Build_rapid", true, false)
	check(is_zero_approx(first_card.global_position.x), label + " no outer side padding")
	check(is_equal_approx(first_card.global_position.y, build.palette.global_position.y), label + " no outer top padding")
	var outside := Vector2(host.size.x * 0.5, build.palette.position.y - 20)
	await touch(outside, true)
	await touch(outside, false)
	await settle()
	check(build.visible and build.palette.visible, label + " outside tap retains cards")
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
		await touch(blocked, true)
		await drag(target)
		check(build.valid, label + " retry preview valid")
		await touch(target, false)
		check(host.game.data.towers.size() == before + 1 and (build.kind.is_empty() and build.palette.visible), label + " retry release builds once")
		check(is_equal_approx(funds - host.game.data.balance, Balance.definition("towers", "rapid", host.game.tuning).cost), label + " spends exact price")
		field.tap(target - field.global_position)
		check(not field.selected_tower.is_empty(), label + " ground tower selectable")
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
	check(build.kind.is_empty() and (scroll.scroll_horizontal > 0 or scroll.get_h_scroll_bar().max_value <= scroll.get_h_scroll_bar().page), label + " horizontal swipe browses without arming")
	check(scroll.find_child("Build_rapid", true, false).global_position.x < 8, label + " edge padding travels with scrolling cards")
	build.arm("rapid")
	await settle()
	var count: int = host.game.data.towers.size()
	await touch(blocked, true)
	await touch(blocked + Vector2(30, 0), true, 1)
	await touch(blocked + Vector2(30, 0), false, 1)
	check(build.dragging and build.pointer == 0 and host.game.data.towers.size() == count, label + " secondary finger cannot commit")
	await drag(Vector2(-30, -30))
	await touch(Vector2(-30, -30), false)
	check(not build.valid and host.game.data.towers.size() == count, label + " offscreen release cannot build")
	var cancel_button: Button = build.banner.find_children("*", "Button", true, false)[0]
	await touch(cancel_button.get_global_rect().get_center(), true)
	await touch(cancel_button.get_global_rect().get_center(), false)
	check((build.kind.is_empty() and build.palette.visible), label + " touch Cancel dismisses preview")
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
