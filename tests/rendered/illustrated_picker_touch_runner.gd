extends SceneTree

var failures := 0

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	preload("res://tests/support/timeout.gd").arm(self, 30)
	call_deferred("run")

func settle() -> void:
	for frame in 8: await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		await check_picker(dimensions)
	print("PICKER TOUCH: aligned portraits, passive drag and button selection at three phone sizes; %d failures" % failures)
	quit(1 if failures else 0)

func check_picker(dimensions: Vector2i) -> void:
	root.size = dimensions
	var picker := preload("res://scripts/ui/shared/illustrated_picker.gd").new()
	root.add_child(picker)
	picker.preview_factory = func(kind: String): return preload("res://scripts/ui/shared/content_portrait.gd").preview("enemies", kind)
	for kind in Balance.ENEMIES:
		picker.add_item(Balance.ENEMIES[kind].name)
		picker.set_item_metadata(picker.item_count - 1, kind)
	picker.select(0)
	picker.show_popup()
	await settle()
	var popup := picker.popup
	check(Rect2i(Vector2i.ZERO, dimensions).encloses(Rect2i(popup.position, popup.size)), "Picker stays within phone width")
	var first_row := picker.rows.get_child(0) as HBoxContainer
	var first_button := first_row.get_child(2) as Button
	for row in picker.rows.get_children():
		var art := row.get_child(0) as Control
		var label := row.get_child(1) as Label
		var action := row.get_child(2) as Button
		check(art.size.x == 64 and art.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Native portrait reserves a passive fixed column")
		check(is_equal_approx(action.size.x, first_button.size.x) and is_equal_approx(action.position.x, first_button.position.x), "Select and Selected columns stay aligned")
		check(label.size.x > 0 and not row is BaseButton, "Enemy title provides passive scrolling space")
		check(row.size.x <= picker.scroll.size.x, "Rows never expand the horizontal layout")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/enemy-picker-%d.png" % dimensions.x)
	var start := picker.scroll.get_global_rect().position + Vector2(110, 240)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	touch.position += Vector2(popup.position)
	Input.parse_input_event(touch)
	await process_frame
	for step in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = start - Vector2(0, step * 20)
		drag.relative = Vector2(0, -20)
		drag.position += Vector2(popup.position)
		Input.parse_input_event(drag)
		await process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start - Vector2(0, 160)
	touch.pressed = false
	touch.position += Vector2(popup.position)
	Input.parse_input_event(touch)
	await settle()
	check(picker.scroll.scroll_vertical > 0, "Dragging the label side scrolls the menu")
	check(popup.visible and picker.selected == 0, "Scrolling never selects or closes the picker")
	var button := picker.rows.find_child("Choice_3", true, false) as Button
	picker.scroll.ensure_control_visible(button.get_parent())
	await settle()
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = button.get_global_rect().get_center()
	touch.pressed = true
	touch.position += Vector2(popup.position)
	Input.parse_input_event(touch)
	await process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = button.get_global_rect().get_center()
	touch.pressed = false
	touch.position += Vector2(popup.position)
	Input.parse_input_event(touch)
	await settle()
	check(not popup.visible and picker.selected == 3, "Tapping the right-hand button selects its item")
	picker.free()
