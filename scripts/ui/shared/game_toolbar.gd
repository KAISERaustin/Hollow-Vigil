extends HBoxContainer
## Shared gameplay control geometry for Campaign and Infinite.
const UI = preload("res://scripts/ui/shared/interface.gd")
const SPEEDS := [1.0, 2.0, 4.0]
var pause_button: Button
var speed_button: Button
var menu_button: Button

func configure(pause: Callable, speed: Callable, menu: Callable, title: String = "", back_label: String = "") -> void:
	name = "GameToolbar"
	add_theme_constant_override("separation", UI.GAP)
	menu_button = UI.button("Menu" if back_label.is_empty() else "←", menu, UI.TOOLBAR_BUTTON_SIZE)
	menu_button.name = "GameMenuButton"
	menu_button.custom_minimum_size.x = 88 if back_label.is_empty() else UI.TOOLBAR_BUTTON_SIZE
	menu_button.accessibility_name = "Menu" if back_label.is_empty() else back_label
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(menu_button)
	if title.is_empty():
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(spacer)
	else:
		var caption := UI.fitted_heading(title, 24, 16)
		caption.name = "GameToolbarTitle"
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(caption)
	pause_button = UI.playback_button(pause)
	pause_button.name = "PauseButton"
	add_child(pause_button)
	speed_button = UI.button("1×", speed, UI.TOOLBAR_BUTTON_SIZE)
	speed_button.name = "SpeedButton"
	speed_button.toggle_mode = true
	speed_button.custom_minimum_size.x = UI.TOOLBAR_BUTTON_SIZE
	speed_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(speed_button)

func update_controls(paused: bool, speed: float) -> void:
	pause_button.set_meta("paused", paused)
	pause_button.accessibility_name = "Resume game" if paused else "Pause game"
	pause_button.queue_redraw()
	update_speed_button(speed_button, speed)

static func next_speed(speed: float) -> float:
	return SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()]

static func update_speed_button(button: Button, speed: float) -> void:
	button.text = "%d×" % int(speed)
	button.set_pressed_no_signal(speed > 1.0)
	button.accessibility_description = "Switch to %d× speed" % int(next_speed(speed))
	button.accessibility_name = "Game speed: %d×. %s" % [int(speed), button.accessibility_description]
