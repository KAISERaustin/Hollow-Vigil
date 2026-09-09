extends "res://tests/touch_scroll_scope_runner.gd"
## Reward dismissal must release both physical and synthesized pointer ownership.
const Reward = preload("res://scripts/ui/shared/reward_transition.gd")

func run() -> void:
	Input.emulate_touch_from_mouse = true
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(390, 844)
	UI.keyboard_scroll(scroll, "Map input fixture")
	root.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(390, 2400)
	scroll.add_child(content)
	var reward := Reward.new()
	root.add_child(reward)
	await settle()
	for device in [0, InputEvent.DEVICE_ID_EMULATION]:
		reward.play("Final wave won", 20)
		reward.set_process(false)
		var event := InputEventMouseButton.new()
		event.device = device
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = Vector2(195, 422)
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		check(not reward.active, "Mouse-first reward dismissal: device %d" % device)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await settle()
		check(reward.dismissed_pointers.is_empty(), "Dismissal release clears pointer ownership: device %d" % device)
		scroll.scroll_vertical = 0
		await settle()
		await swipe(Vector2(195, 422))
		check(scroll.scroll_vertical > 30, "Map swipes work after reward dismissal: device %d" % device)
	reward.queue_free()
	scroll.queue_free()
	await settle()
	print("REWARD INPUT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
