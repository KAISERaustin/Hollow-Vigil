extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var field := Battlefield.new()
	field.state = VigilState.new(8)
	for viewport in [Vector2(540, 900), Vector2(1200, 600), Vector2(2400, 1800)]:
		field.size = viewport
		field.set_zoom(0.001, viewport * 0.5)
		check(minf(viewport.x, viewport.y) / field.zoom <= 2 * Balance.TILE + 0.01, "Two tile zoom limit")
		for direction in [Vector2.ONE, -Vector2.ONE, Vector2(1, -1), Vector2(-1, 1)]:
			field.camera = direction * 100000
			field.enforce_camera_limits()
			check(field.camera_bounds().grow(0.01).encloses(Rect2(field.world(Vector2.ZERO), viewport / field.zoom)), "Viewport boundary")
	field.state.data.regions["3,0"] = VigilWorld.make_region("3,0", "2,0", 8)
	check(is_equal_approx(field.camera_bounds().end.x, 5.5 * Balance.TILE), "Protruding tile envelope")
	field.set_unrestricted_camera(true)
	field.camera = Vector2(10000, 10000)
	field.set_zoom(0.05, field.size * 0.5)
	check(is_equal_approx(field.zoom, 0.05) and field.camera.x == 10000, "Bypass zoom out and pan")
	field.set_zoom(10, field.size * 0.5)
	check(field.zoom == 10, "Bypass zoom in")
	var controls := preload("res://scripts/ui/developer_controls.gd").new()
	controls.game = field.state
	controls.field = field
	root.add_child(controls)
	var toggle := controls.get_node("UnrestrictedCamera") as Button
	check(toggle.button_pressed, "Toggle reflects bypass")
	toggle.button_pressed = false
	check(not field.unrestricted_camera and field.camera.x < 10000 and field.zoom <= maxf(1.65, field.minimum_zoom()), "Toggle restores limits immediately")
	controls.free()
	field.free()
	print("CAMERA RESULT: 20 checks, %d failures" % failures)
	quit(1 if failures else 0)
