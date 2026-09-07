extends RefCounted

static func run(suite: SceneTree) -> void:
	test_gestures(suite)
	test_portal_controls(suite)

static func test_gestures(suite: SceneTree) -> void:
	var g: VigilState = suite.legacy_core_fixture(8)
	var field := Battlefield.new()
	field.state = g
	field.size = Vector2(540, 620)
	suite.root.add_child(field)
	var taps := [0]
	field.picked.connect(func(_r, _p): taps[0] += 1)
	var at := field.screen(VigilWorld.pad_position("0,0", 0))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	field._on_gui_input(press)
	var release := press.duplicate()
	release.pressed = false
	field._on_gui_input(release)
	suite.check(taps[0] == 1, "Tap selects a tower")
	field._on_gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = at + Vector2(40, 0)
	field._on_gui_input(drag)
	release.position = drag.position
	field._on_gui_input(release)
	suite.check(taps[0] == 1 and field.camera != Vector2.ZERO, "Drag pans without selecting or purchasing")
	field.camera = Vector2.ZERO
	for i in range(2):
		var touch := InputEventScreenTouch.new()
		touch.index = i
		touch.position = at + Vector2(i * 70, 0)
		touch.pressed = true
		field._on_gui_input(touch)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 1
	touch_drag.position = at + Vector2(110, 0)
	field._on_gui_input(touch_drag)
	for i in range(2):
		var touch := InputEventScreenTouch.new()
		touch.index = i
		touch.position = at
		touch.pressed = false
		field._on_gui_input(touch)
	suite.check(field.zoom > 1 and taps[0] == 1, "Pinch zooms without releasing a purchase tap")
	suite.check(g.data.balance == Balance.STARTING_GOLD and g.data.towers.is_empty(), "Gestures never commit financial actions")
	var badge_taps := [0]
	field.earnings_picked.connect(func(_id): badge_taps[0] += 1)
	g.economy.build("rapid", "0,0", 0)
	g.economy.credit("1", 5)
	field.tap(field.earnings_rect(g.data.towers["1"]).get_center())
	suite.check(badge_taps[0] == 0, "Removed tower earnings badge has no collection hit target")
	press.device = -1
	field._on_gui_input(press)
	suite.check(not field.mouse_down, "Mouse events emulated from touch cannot start a duplicate gesture")
	var core_taps := [0]
	field.core_picked.connect(func(): core_taps[0] += 1)
	for scale in [0.42, 0.65, 1.0, 1.65]:
		field.camera = Vector2.ZERO
		field.zoom = scale
		var core_before: int = core_taps[0]
		field.tap(field.screen(Vector2.ZERO))
		suite.check(core_taps[0] == core_before + 1, "Core artwork is tappable at zoom %.2f" % scale)
		var pads_before: int = taps[0]
		for pad in range(4):
			field.tap(field.screen(VigilWorld.pad_position("0,0", pad)))
		suite.check(taps[0] == pads_before + 4 and core_taps[0] == core_before + 1, "Core hit targets leave all surrounding sockets selectable at zoom %.2f" % scale)
	field.camera = Vector2(3000, 3000)
	suite.check(not field.core_is_visible(), "Offscreen core is not visible")
	field.camera = Vector2.ZERO
	field.zoom = 1.0
	press.device = 0
	press.position = field.screen(Vector2.ZERO)
	field._on_gui_input(press)
	release.position = press.position + field.global_position
	field._input(release)
	suite.check(field.mouse_down, "An inside release uses its event position and reaches the map gesture handler")
	var core_before: int = core_taps[0]
	release.position = press.position
	field._on_gui_input(release)
	suite.check(core_taps[0] == core_before + 1 and not field.mouse_down, "A complete mouse gesture selects the core once")
	field._on_gui_input(press)
	release.position = field.global_position - Vector2(20, 20)
	field._input(release)
	suite.check(not field.mouse_down and core_taps[0] == core_before + 1, "Releasing outside the map ends the gesture without selecting the core")
	field.free()
	print("PASS GROUP: tap, pan, and pinch conflicts")

static func test_portal_controls(suite: SceneTree) -> void:
	var g := VigilState.new(8)
	g.data.balance = 100000.0
	g.data.towers.clear()
	for direction in VigilWorld.DIRS:
		g.expand(VigilWorld.key(direction))
	var field := Battlefield.new()
	field.state = g
	field.size = Vector2(540, 620)
	suite.root.add_child(field)
	var chosen := {"kind": "", "id": ""}
	field.entrance_picked.connect(func(id): chosen.kind = "rift"; chosen.id = id)
	field.expansion_picked.connect(func(id): chosen.kind = "expand"; chosen.id = id)
	field.picked.connect(func(_id, _pad): chosen.kind = "socket")
	field.core_picked.connect(func(): chosen.kind = "core")
	field.earnings_picked.connect(func(_id): chosen.kind = "gold")
	for scale in [0.42, 0.65, 1.0, 1.65]:
		field.zoom = scale
		suite.check(is_equal_approx(field.entrance_scale() / scale, 1.0), "Rift keeps a fixed map size at zoom %.2f" % scale)
		for direction in VigilWorld.DIRS:
			var id := VigilWorld.key(direction)
			var frontier := VigilWorld.key(direction * 2)
			field.camera = VigilWorld.center(id) + Vector2(direction) * 150.0
			var gate: Vector2 = field.screen(g.paths[id][0])
			var expand := field.screen(field.expansion_marker(frontier))
			suite.check(expand.is_equal_approx(field.screen(VigilWorld.center(frontier))), "Expansion is centered on its future tile at zoom %.2f" % scale)
			var outward := gate.direction_to(expand)
			var rift_edge := gate + outward * (field.entrance_hit_radius() - 2.0)
			var expand_edge: Vector2 = expand - outward * (Battlefield.EXPANSION_HIT_RADIUS * scale - 2.0)
			suite.check(gate.distance_to(expand) > field.entrance_hit_radius() + Battlefield.EXPANSION_HIT_RADIUS * scale, "Rift %s and expansion keep separate touch areas at zoom %.2f" % [id, scale])
			for point in [gate, rift_edge]:
				chosen.kind = ""
				field.tap(point)
				suite.check(chosen.kind == "rift" and chosen.id == id, "Portal center and edge select its upgrades at zoom %.2f" % scale)
			for point in [expand, expand_edge]:
				chosen.kind = ""
				field.tap(point)
				suite.check((chosen.kind == "expand" and chosen.id == frontier) if VigilWorld.frontier(g.data.regions, int(g.data.seed)).has(frontier) else chosen.kind == "", "Expansion center and edge select the correct territory at zoom %.2f" % scale)
			chosen.kind = ""
			field.tap((rift_edge + expand_edge) * 0.5)
			suite.check(chosen.kind == "", "Gap between portal and expansion does not select either at zoom %.2f" % scale)
	# A frontier enclosed on several sides can have crowded padding at minimum
	# zoom. Its visible center must still win over a nearby rift's touch padding.
	for id in ["-1,-1", "-1,-2", "0,-2", "1,-2", "1,-1"]:
		g.expand(id)
	field.zoom = 0.42
	for id in VigilWorld.frontier(g.data.regions, int(g.data.seed)):
		chosen.kind = ""
		field.tap(field.screen(field.expansion_marker(id)))
		suite.check(chosen.kind == "expand" and chosen.id == id, "Crowded frontier %s remains selectable at minimum zoom" % id)
	var tower := g.economy.build("splash", "0,0", 2)
	g.economy.credit(tower, 161.0)
	field.camera = Vector2.ZERO
	chosen.kind = ""
	field.tap(field.screen(g.paths["-1,0"][0]))
	suite.check(chosen.kind == "rift" and chosen.id == "-1,0", "Nearby earnings padding cannot steal the portal click at minimum zoom")
	field.tap(field.earnings_rect(g.data.towers[tower]).get_center())
	suite.check(chosen.kind != "gold", "Removed earnings badge cannot collect beside a portal at minimum zoom")
	field.zoom = 1.0
	var badge: Rect2 = field.earnings_rect(g.data.towers[tower])
	var anchor := VigilWorld.pad_position("0,0", 2)
	var badge_offset := badge.position - field.screen(anchor)
	field.set_unrestricted_camera(true) # Exercise artwork scaling below the gameplay zoom limit.
	for scale in [0.42, 0.65, 1.0, 1.65]:
		field.set_zoom(scale, field.size * 0.5)
		field.camera += Vector2(12, -8)
		var current := field.earnings_rect(g.data.towers[tower])
		suite.check((current.size / scale).is_equal_approx(badge.size) and ((current.position - field.screen(anchor)) / scale).is_equal_approx(badge_offset), "Earnings badge stays fixed above its tower in map space at zoom %.2f" % scale)
		field.selected_tower = tower
		for point in [current.get_center(), Vector2(current.end.x + 4.0 * scale, current.get_center().y)]:
			chosen.kind = ""
			field.tap(point)
			suite.check(chosen.kind != "gold", "Hidden earnings badge or its padding intercepted input at zoom %.2f" % scale)
		field.selected_tower = ""
		chosen.kind = ""
		field.tap(current.get_center())
		suite.check(chosen.kind != "gold" and not field.earnings_badge_visible(g.data.towers[tower]), "Tower earnings badge stays hidden and cannot collect after pan and zoom %.2f" % scale)
	field.free()
	print("PASS GROUP: portal and expansion separation in four directions at every zoom")
