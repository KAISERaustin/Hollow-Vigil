extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	root.gui_embed_subwindows = true
	preload("res://tests/support/timeout.gd").arm(self, 90)
	call_deferred("run")

func settle() -> void:
	for frame in 8: await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960), Vector2i(844, 390)]:
		await check_picker(dimensions)
	print("PICKER TOUCH: %d checks, %d failures; taps, passive/action drags, cancellation, disabled items, rotation and dismissal at four sizes" % [checks, failures])
	quit(1 if failures else 0)

func touch(at: Vector2, pressed: bool, canceled: bool = false, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	event.index = index
	Input.parse_input_event(event)
	await process_frame

func tap(at: Vector2, canceled: bool = false) -> void:
	await touch(at, true)
	await touch(at, false, canceled)
	await settle()

func swipe(at: Vector2, delta: Vector2 = Vector2(0, -96)) -> void:
	await touch(at, true)
	for step in 8:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = at + delta * float(step + 1) / 8.0
		event.relative = delta / 8.0
		Input.parse_input_event(event)
		await process_frame
	await touch(at + delta, false)
	await settle()

func choice_position(picker: Button, index: int) -> Vector2:
	var action: Button = picker.rows.find_child("Choice_" + str(index), true, false)
	picker.scroll.ensure_control_visible(action.get_parent())
	await settle()
	return Vector2(picker.popup.position) + action.get_global_rect().get_center()

func check_picker(dimensions: Vector2i) -> void:
	root.size = dimensions
	root.content_scale_size = dimensions
	var picker := preload("res://scripts/ui/shared/illustrated_picker.gd").new()
	root.add_child(picker)
	picker.preview_factory = func(kind: String): return preload("res://scripts/ui/shared/content_portrait.gd").preview("enemies", kind)
	for kind in Balance.ENEMIES:
		picker.add_item(Balance.ENEMIES[kind].name)
		picker.set_item_metadata(picker.item_count - 1, kind)
	picker.select(0)
	picker.position = Vector2(12, 12)
	picker.size = Vector2(dimensions.x - 24, 48)
	await settle()
	await tap(picker.get_global_rect().get_center())
	await settle()
	var popup := picker.popup
	check(popup.visible, "Physical touch opens illustrated picker")
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
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/enemy-picker-%d.png" % dimensions.x)
	var rotated := Vector2i(dimensions.y, dimensions.x)
	root.size = rotated
	root.content_scale_size = rotated
	await settle()
	check(Rect2i(Vector2i(12, 12), rotated - Vector2i(24, 24)).encloses(Rect2i(popup.position, popup.size)), "Open picker refits after rotation from " + str(dimensions))
	check(popup.visible and picker.selected == 0, "Rotation preserves the open selection")
	root.size = dimensions
	root.content_scale_size = dimensions
	await settle()
	check(Rect2i(Vector2i(12, 12), dimensions - Vector2i(24, 24)).encloses(Rect2i(popup.position, popup.size)), "Open picker refits after returning from rotation")
	var start := picker.scroll.get_global_rect().position + Vector2(110, minf(240, picker.scroll.size.y - 20))
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
	var action_start := await choice_position(picker, 3)
	var scroll_before: int = picker.scroll.scroll_vertical
	await swipe(action_start)
	check(picker.scroll.scroll_vertical > scroll_before, "Dragging a Select button scrolls")
	check(popup.visible and picker.selected == 0, "Dragging a Select button never commits a choice")
	await tap(await choice_position(picker, 3), true)
	check(popup.visible and picker.selected == 0, "Canceled touch does not commit a choice")
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
	picker.show_popup()
	await settle()
	var close: Button = popup.get_child(0).get_child(0).get_child(0).get_child(1)
	await tap(Vector2(popup.position) + close.get_global_rect().get_center())
	check(not popup.visible and picker.selected == 3, "Touch Close dismisses without changing the selection")
	picker.show_popup()
	await settle()
	await tap(Vector2(2, 2))
	check(not popup.visible and picker.selected == 3, "Outside touch dismisses without choosing")
	picker.free()
	# Slot/scope pickers preserve disabled destinations and provide artwork
	# even when their choices are not enemies or another content family.
	var options := preload("res://scripts/ui/shared/illustrated_picker.gd").new()
	options.illustration = "slots"
	options.add_item("Empty slot")
	options.add_item("Recovery needed")
	options.set_item_disabled(1, true)
	root.add_child(options)
	options.show_popup()
	await settle()
	check(options.selected == 0, "Operational choices retain the first default")
	check(options.rows.get_child(0).get_child_count() == 3, "Operational choices include artwork and passive labels")
	check((options.rows.get_child(1).get_child(2) as Button).disabled, "Unavailable destinations disable their selection button")
	await tap(await choice_position(options, 1))
	check(options.selected == 0 and options.popup.visible, "Unavailable destination cannot be selected")
	options.popup.hide()
	options.disabled = true
	options.show_popup()
	check(not options.popup.visible, "Busy destination pickers stay closed")
	options.free()
