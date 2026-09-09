extends SceneTree
## Exercise the real starting economy and both pointer paths, without platform fixtures.
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
	for frame in 12: await process_frame
	await create_timer(0.2).timeout

func pointer(at: Vector2, pressed: bool, mouse: bool) -> void:
	var event: InputEvent
	if mouse:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
	else:
		event = InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func motion(at: Vector2, relative: Vector2, mouse: bool) -> void:
	var event: InputEvent
	if mouse:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	else:
		event = InputEventScreenDrag.new()
	event.position = at
	event.relative = relative
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://infinite-placement-regression.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.slot_menu = Control.new()
	app.add_child(app.slot_menu)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		for mouse in [false, true]:
			root.size = viewport
			root.content_scale_size = viewport
			var fresh := VigilState.new(771)
			fresh.save_path = "user://infinite-placement-regression.save"
			app.activate_slot(fresh, 0)
			app.toggle_pause() # Freeze enemies while keeping normal rendering/input active.
			app.ground_build.open()
			await settle()
			var label := "%s %d" % ["mouse" if mouse else "touch", viewport.x]
			check(app.game.economy.needs_first_property(), label + " starts with real onboarding")
			var locked_card: Button = app.ground_build.palette.find_child("Build_rapid", true, false)
			var locked_start := locked_card.get_global_rect().get_center()
			await pointer(locked_start, true, mouse)
			await pointer(locked_start, false, mouse)
			check(app.toast_label.text == "Claim your first territory before placing towers.", label + " explains first territory requirement")
			check(app.game.data.towers.is_empty() and app.game.data.balance == Balance.STARTING_GOLD, label + " locked selection spends nothing")
			app.ground_build.cancel()
			await settle()
			var frontier: Dictionary = VigilWorld.frontier(app.game.data.regions, int(app.game.data.seed))
			app.panels.show_expansion(frontier.keys()[0])
			await settle()
			var claim := app.panels.action_button.get_global_rect().get_center()
			await pointer(claim, true, mouse)
			await pointer(claim, false, mouse)
			await settle()
			check(not app.game.economy.needs_first_property(), label + " property purchase unlocks building")
			var build: Control = app.ground_build
			var button: Button = build.palette.find_child("Build_rapid", true, false)
			var start := button.get_global_rect().get_center()
			await pointer(start, true, mouse)
			await motion(start - Vector2(0, 40), Vector2(0, -40), mouse)
			await settle()
			check(build.dragging and build.kind == "rapid", label + " toolbar drag picks up tower")
			var target := Vector2.INF
			for y in range(110, int(app.field.size.y) - 75, 10):
				for x in range(25, int(app.field.size.x) - 25, 10):
					var screen_point := app.field.global_position + Vector2(x, y)
					var world_point := app.field.world(Vector2(x, y))
					if app.game.economy.ground_allowed(world_point) and not build.banner.get_global_rect().has_point(screen_point):
						target = screen_point
						break
				if target.is_finite(): break
			check(target.is_finite(), label + " clear owned ground is reachable")
			if target.is_finite():
				var funds: float = app.game.data.balance
				await motion(target, target - start, mouse)
				check(build.valid, label + " valid ground preview")
				await pointer(target, false, mouse)
				check(app.game.data.towers.size() == 1, label + " release builds exactly one tower")
				check(is_equal_approx(funds - app.game.data.balance, Balance.definition("towers", "rapid", app.game.tuning).cost), label + " spends exact price")
				await create_timer(4.0).timeout # Let the onboarding toast expire before capture.
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/infinite-placement-%s-%d.png" % ["mouse" if mouse else "touch", viewport.x])
			app.ground_build.cancel()
	app.queue_free()
	await settle()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://infinite-placement-regression.save" + suffix)
	print("INFINITE PLACEMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
