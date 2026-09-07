extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func settle(field: Battlefield, actions: VigilTowerActions) -> void:
	for step in range(40):
		field._process(1.0 / 60.0)
		actions.refresh()

func check_buttons(field: Battlefield, actions: VigilTowerActions, label: String) -> void:
	var available := Rect2(field.global_position + Vector2(9, 9), field.size - Vector2(18, 18))
	if actions.upgrade_quote.visible:
		available.size.y = actions.upgrade_quote.global_position.y - 9 - available.position.y
	for button in actions.buttons.values():
		check(available.encloses(button.get_global_rect()), label + " fits " + button.name)
	if actions.branch_bar.visible:
		for button in actions.branch_bar.get_children():
			check(available.encloses(button.get_global_rect()), label + " fits " + button.name)
	var tower: Dictionary = field.state.data.towers[field.selected_tower]
	var radius: float = Balance.tower_stats(tower, field.state.tuning).range * field.zoom
	var center := field.global_position + field.screen(VigilWorld.pad_position(tower.region, tower.pad))
	check(available.encloses(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)), label + " fits full yellow range circle")
	check(not field.camera_framing.active, label + " finishes drift")
	check(field.camera_bounds().grow(0.1).encloses(Rect2(field.world(Vector2.ZERO), field.size / field.zoom)), label + " respects camera limits")

func exercise(host: Control, id: String, select: Callable, label: String) -> void:
	var field: Battlefield = host.field
	var actions: VigilTowerActions = host.tower_actions
	field.set_process(false)
	actions.set_process(false)
	var tower: Dictionary = host.game.data.towers[id]
	var world_position := VigilWorld.pad_position(tower.region, tower.pad)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await frame()
		for desired_zoom in [0.65, 1.0, 1.65]:
			field.set_zoom(desired_zoom, field.size * 0.5)
			var zoom := field.zoom
			for level in [1, 3, 4]:
				tower.level = level
				for edge in [Vector2(0.02, 0.5), Vector2(0.98, 0.5), Vector2(0.5, 0.02), Vector2(0.5, 0.98), Vector2(0.02, 0.02), Vector2(0.98, 0.98)]:
					field.set_zoom(desired_zoom, field.size * 0.5)
					zoom = field.zoom
					field.selected_tower = ""
					actions.refresh()
					field.camera = world_position - (field.size * edge - field.size * 0.5) / zoom
					field.enforce_camera_limits()
					var before := field.camera
					select.call()
					actions.refresh()
					check(field.camera == before, label + " starts without a jump")
					await frame()
					actions.refresh()
					var destination := field.camera_framing.target
					if field.camera_framing.active:
						field._process(0.1)
						check(field.camera.distance_to(before) > 0 and field.camera.distance_to(before) < destination.distance_to(before) * 0.25, label + " eases into drift")
					settle(field, actions)
					var available_size := field.size - Vector2(20, 20)
					if actions.upgrade_quote.visible:
						available_size.y = actions.upgrade_quote.position.y - 20
					var diameter: float = maxf(204.0, Balance.tower_stats(tower, field.state.tuning).range * 2.0)
					var expected_zoom := minf(zoom, maxf(field.minimum_zoom(), minf(available_size.x, available_size.y) / diameter))
					check(is_equal_approx(field.zoom, expected_zoom), label + " preserves zoom unless the cluster cannot fit")
					check_buttons(field, actions, "%s %s zoom %.2f level %d edge %s" % [label, viewport, zoom, level, edge])
					var arrived := field.camera
					select.call()
					settle(field, actions)
					check(field.camera.is_equal_approx(arrived), label + " leaves a visible menu still")
				# Save the real rendered before/after at the narrowest phone width.
				if viewport.x == 360 and desired_zoom == 1.0 and level == 3:
					field.camera = world_position - Vector2(field.size.x * 0.5 - 15, 0) / zoom
					field.enforce_camera_limits()
					select.call()
					actions.refresh()
					field.queue_redraw()
					await frame()
					root.get_texture().get_image().save_png("res://artifacts/tower-framing-" + label + "-before.png")
					settle(field, actions)
					await frame()
					root.get_texture().get_image().save_png("res://artifacts/tower-framing-" + label + "-after.png")
	# Interrupt a pending drift through the actual input handlers.
	for input_kind in ["mouse", "touch", "zoom", "deselect", "modal"]:
		field.selected_tower = ""
		actions.refresh()
		field.camera = world_position - Vector2(field.size.x * 0.5 - 15, 0) / field.zoom
		field.enforce_camera_limits()
		select.call()
		actions.refresh()
		check(field.camera_framing.active, label + " interruption fixture starts drift")
		if input_kind == "mouse":
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = field.size * 0.5
			field._on_gui_input(press)
			var drag := InputEventMouseMotion.new()
			drag.position = press.position + Vector2(35, 0)
			field._on_gui_input(drag)
			press.pressed = false
			press.position = drag.position
			field._on_gui_input(press)
		elif input_kind == "touch":
			var press := InputEventScreenTouch.new()
			press.pressed = true
			press.position = field.size * 0.5
			field._on_gui_input(press)
			var drag := InputEventScreenDrag.new()
			drag.position = press.position + Vector2(35, 0)
			field._on_gui_input(drag)
			press.pressed = false
			press.position = drag.position
			field._on_gui_input(press)
		elif input_kind == "zoom":
			field.set_zoom(field.zoom * 0.9, field.size * 0.5)
		elif input_kind == "deselect":
			field.selected_tower = ""
		else:
			host.tower_dialog.open_action("info")
		var stopped := field.camera
		settle(field, actions)
		check(not field.camera_framing.active and field.camera.is_equal_approx(stopped), label + " yields to " + input_kind)
		if input_kind == "modal":
			host.tower_dialog.dismiss()
	settle(field, actions)
	check_buttons(field, actions, label + " returns from modal")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://tower-framing-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.balance = 100000
	app.game.expand("1,0")
	var id := app.game.economy.build("rapid", "0,0", 0)
	await frame()
	await exercise(app, id, func(): app.panels.select_pad("0,0", 0), "infinite")
	app.panels.close_sheet()
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.start_mission(0)
	campaign.game.data.balance = 100000
	var socket: int = campaign.run.mission.sockets[1].index
	campaign.run.build(socket, "heavy")
	id = campaign.run.tower_at(socket)
	await frame()
	await exercise(campaign, id, func(): campaign.show_socket(socket), "campaign")
	check(app.field.camera_framing != campaign.field.camera_framing, "Modes own independent framing state")
	app.free()
	print("TOWER FRAMING: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
