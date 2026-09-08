extends "res://tests/test_runner.gd"
const TouchScroll = preload("res://scripts/ui/shared/touch_scroll.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")

func run() -> void:
	var scroll := ScrollContainer.new()
	root.add_child(scroll)
	TouchScroll.attach(scroll)
	var layout := VBoxContainer.new()
	scroll.add_child(layout)
	var first := Button.new()
	layout.add_child(first)
	check(first.mouse_filter == Control.MOUSE_FILTER_PASS, "Buttons inside scroll allow gestures")
	layout.reparent(root, false)
	check(first.mouse_filter == Control.MOUSE_FILTER_STOP, "Reparenting restores original button input boundary")
	var second := Button.new()
	layout.add_child(second)
	check(second.mouse_filter == Control.MOUSE_FILTER_STOP, "Stale scroll observer cannot change new battlefield controls")
	layout.reparent(scroll, false)
	check(first.mouse_filter == Control.MOUSE_FILTER_PASS and second.mouse_filter == Control.MOUSE_FILTER_PASS, "Returning to scroll prepares controls again")
	var nested := ScrollContainer.new()
	layout.add_child(nested)
	var nested_button := Button.new()
	nested.add_child(nested_button)
	check(nested_button.mouse_filter == Control.MOUSE_FILTER_STOP, "Nested scroll retains its own gesture boundary")
	var picker := OptionButton.new()
	var original_action := picker.action_mode
	var original_fit := picker.fit_to_longest_item
	layout.add_child(picker)
	check(picker.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE and not picker.fit_to_longest_item, "Dropdown allows a swipe to finish before opening")
	layout.reparent(root, false)
	check(picker.action_mode == original_action and picker.fit_to_longest_item == original_fit, "Dropdown input and sizing restored outside scroll owner")
	layout.reparent(scroll, false)
	check(picker.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "Dropdown can reattach without stale popup callbacks")
	scroll.queue_free()
	await process_frame
	await check_rebuilt_range()
	await check_gestures()
	print("TOUCH SCROLL SCOPE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for frame in 8: await process_frame

func touch(at: Vector2, down: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = down
	event.index = index
	event.canceled = canceled
	Input.parse_input_event(event)
	await process_frame

func tap(at: Vector2) -> void:
	await touch(at, true)
	await touch(at, false)
	await settle()

func swipe(at: Vector2) -> void:
	await touch(at, true)
	for step in 8:
		var event := InputEventScreenDrag.new()
		event.position = at - Vector2(0, 12 * (step + 1))
		event.relative = Vector2(0, -12)
		event.index = 0
		Input.parse_input_event(event)
		await process_frame
	await touch(at - Vector2(0, 96), false)
	await settle()

func check_rebuilt_range() -> void:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(320, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	TouchScroll.attach(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var page := Control.new()
	page.custom_minimum_size = Vector2(280, 1200)
	content.add_child(page)
	await settle()
	check(scroll.get_v_scroll_bar().max_value == 1200, "Initial tall page exposes its complete scroll range")
	for revision in 3:
		content.remove_child(page)
		page.queue_free()
		# Page fitting can measure the container between removal and replacement.
		# The replacement's identical minimum must still refresh the native range.
		scroll.get_minimum_size()
		page = Control.new()
		page.custom_minimum_size = Vector2(280, 1200)
		content.add_child(page)
		var last := Button.new()
		last.position = Vector2(12, 1140)
		last.size = Vector2(120, 48)
		page.add_child(last)
		await settle()
		check(scroll.get_v_scroll_bar().max_value == 1200, "Same-size rebuilt page retains its full range: " + str(revision))
		scroll.ensure_control_visible(last)
		await settle()
		check(scroll.get_global_rect().encloses(last.get_global_rect()), "Last control stays reachable after equal-size page replacement: " + str(revision))
	# A queued refresh must be harmless when its owning page closes immediately.
	page.add_child(Control.new())
	scroll.queue_free()
	await settle()

func check_gestures() -> void:
	Input.emulate_touch_from_mouse = true
	root.gui_embed_subwindows = true
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 12)
	scroll.size = Vector2(366, 400)
	scroll.theme = UI.theme()
	UI.keyboard_scroll(scroll, "Touch fixture")
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var activations := [0]
	var action := UI.button("Action", func(): activations[0] += 1)
	content.add_child(action)
	var entry := LineEdit.new()
	entry.custom_minimum_size.y = 48
	entry.text = "Editable text"
	content.add_child(entry)
	var dropdown := OptionButton.new()
	dropdown.custom_minimum_size.y = 48
	dropdown.add_item("First choice")
	dropdown.add_item("Second choice")
	content.add_child(dropdown)
	var nested := ScrollContainer.new()
	nested.custom_minimum_size.y = 180
	UI.keyboard_scroll(nested, "Nested choices")
	content.add_child(nested)
	var nested_content := VBoxContainer.new()
	nested_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nested.add_child(nested_content)
	for i in 12: nested_content.add_child(UI.button("Nested choice %d" % i, func(): activations[0] += 1))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 800
	content.add_child(spacer)
	await settle()
	await tap(action.get_global_rect().get_center())
	check(activations[0] == 1, "Physical tap activates a scroll child exactly once")
	await touch(action.get_global_rect().get_center(), true)
	await touch(action.get_global_rect().get_center(), false, 0, true)
	await settle()
	check(activations[0] == 1, "Canceled physical touch does not activate a scroll child")
	await touch(action.get_global_rect().get_center(), true)
	await touch(entry.get_global_rect().get_center(), true, 1)
	await touch(entry.get_global_rect().get_center(), false, 1)
	check(activations[0] == 1, "Second finger release cannot activate the first finger's button")
	await touch(action.get_global_rect().get_center(), false)
	await settle()
	check(activations[0] == 2, "Primary finger remains a single action after a second finger releases")
	await swipe(action.get_global_rect().get_center())
	check(scroll.scroll_vertical > 30 and activations[0] == 2, "Dragging over an action scrolls without activating it")
	scroll.scroll_vertical = 0
	await settle()
	await tap(entry.get_global_rect().get_center())
	check(entry.has_focus() and entry.mouse_filter == Control.MOUSE_FILTER_STOP, "Touch focuses native editable text without changing its input boundary")
	var scroll_before := scroll.scroll_vertical
	await swipe(entry.get_global_rect().get_center())
	check(scroll.scroll_vertical == scroll_before and entry.text == "Editable text", "Text selection gesture stays inside its editor")
	entry.release_focus()
	await touch(dropdown.get_global_rect().get_center(), true)
	check(not dropdown.get_popup().visible, "Dropdown never opens on touch down")
	await touch(dropdown.get_global_rect().get_center(), false, 0, true)
	await settle()
	check(not dropdown.get_popup().visible, "Canceled dropdown touch does not open the menu")
	await swipe(dropdown.get_global_rect().get_center())
	check(scroll.scroll_vertical > 30 and not dropdown.get_popup().visible, "Dropdown swipe scrolls its owning page without opening")
	scroll.scroll_vertical = 0
	await settle()
	await tap(dropdown.get_global_rect().get_center())
	check(dropdown.get_popup().visible, "Dropdown opens on a completed physical tap")
	dropdown.get_popup().hide()
	await settle()
	scroll.scroll_vertical = 0
	await settle()
	await swipe(nested.get_global_rect().get_center())
	check(nested.scroll_vertical > 30 and scroll.scroll_vertical == 0, "Nested scroll owns its physical drag without moving the outer page")
	check(activations[0] == 2, "Nested scrolling does not activate any choice")
	scroll.queue_free()
	await settle()
