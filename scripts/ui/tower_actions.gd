class_name VigilTowerActions
extends Control

const UI = preload("res://scripts/ui/interface.gd")
const BUTTON_SIZE := Vector2(48, 48)
const ACTION_OFFSETS := {
	"info": Vector2(-78, 0),
	"upgrade": Vector2(0, 78),
	"sell": Vector2(78, 0)
}
signal action_requested(action: String)
var field: Battlefield
var buttons: Dictionary = {}
var blocked := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for action in ["info", "upgrade", "sell"]:
		var button := Button.new()
		button.size = BUTTON_SIZE
		button.name = "Tower" + action.capitalize()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus"]:
			var color := UI.PANEL if state == "hover" else (UI.DANGER if action == "sell" else UI.GOLD)
			var style := UI.focus_box() if state == "focus" else UI.box(color)
			style.set_content_margin_all(0)
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(func(): action_requested.emit(action))
		button.draw.connect(draw_icon.bind(button, action))
		add_child(button)
		buttons[action] = button
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	visible = not blocked and field.state.data.towers.has(field.selected_tower)
	if not visible:
		return
	var tower: Dictionary = field.state.data.towers[field.selected_tower]
	var center := field.screen(VigilWorld.pad_position(tower.region, tower.pad))
	if not Rect2(Vector2.ZERO, field.size).has_point(center):
		hide()
		return
	# Fixed map dimensions keep the controls proportional to their tower.
	for action in ACTION_OFFSETS:
		var button: Button = buttons[action]
		button.scale = Vector2.ONE * field.zoom
		button.position = center + (ACTION_OFFSETS[action] - BUTTON_SIZE * 0.5) * field.zoom

func draw_icon(button: Button, action: String) -> void:
	var center := button.size * 0.5
	var color := UI.TEXT
	if action == "info":
		button.draw_arc(center, 11, 0, TAU, 40, color, 3, true)
		button.draw_circle(center + Vector2(0, -5), 2, color)
		button.draw_line(center + Vector2(0, -1), center + Vector2(0, 6), color, 3, true)
	elif action == "upgrade":
		for y in [-3, 5]:
			button.draw_polyline(PackedVector2Array([center + Vector2(-9, y + 3), center + Vector2(0, y - 5), center + Vector2(9, y + 3)]), color, 3, true)
	else:
		button.draw_arc(center, 11, 0, TAU, 40, color, 3, true)
		button.draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), color, 3, true)
