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
	root.size = Vector2i(360, 640)
	var picker := preload("res://scripts/ui/shared/illustrated_picker.gd").new()
	root.add_child(picker)
	picker.preview_factory = func(kind: String): return preload("res://scripts/ui/shared/interface.gd").enemy_preview(kind)
	for kind in Balance.ENEMIES:
		picker.add_item(Balance.ENEMIES[kind].name)
		picker.set_item_metadata(picker.item_count - 1, kind)
	picker.select(0)
	picker.show_popup()
	await settle()
	var popup := picker.popup
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
	print("PICKER TOUCH: left-side drag and right-side selection; %d failures" % failures)
	quit(1 if failures else 0)
