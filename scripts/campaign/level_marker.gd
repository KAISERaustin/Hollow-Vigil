extends Button

const UI = preload("res://scripts/ui/shared/interface.gd")
const ClearedArt = preload("res://scripts/campaign/cleared_level_art.gd")
var number := 1
var completed := false
var gate: Texture2D

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _draw() -> void:
	var active := not disabled and has_focus()
	var paper := UI.GOLD if active else Color("e8ddbd")
	var offset := Vector2(0, 2) if button_pressed else Vector2.ZERO
	if completed:
		if active:
			draw_style_box(UI.surface(Color(0,0,0,0), 2, 4), Rect2(Vector2.ZERO, size))
		ClearedArt.draw(self, offset, gate != null)
		if gate != null:
			var plaque := Rect2(size.x * 0.5 - 18, size.y - 21, 36, 22)
			draw_style_box(UI.surface(paper, 2, 2), plaque)
			draw_string(UI.font(600), plaque.position + Vector2(6, 16), str(number), HORIZONTAL_ALIGNMENT_CENTER, 24, 14, UI.TEXT)
		else:
			draw_string(UI.font(600), Vector2(9,40)+offset, str(number), HORIZONTAL_ALIGNMENT_CENTER, 26, 16, UI.TEXT)
		return
	if gate != null:
		draw_texture_rect(gate, Rect2(Vector2.ZERO, size), false)
		var plaque := Rect2(size.x * 0.5 - 18, size.y - 21, 36, 22)
		draw_style_box(UI.surface(paper, 2, 2), plaque)
		draw_string(UI.font(600), plaque.position + Vector2(6, 16), str(number), HORIZONTAL_ALIGNMENT_CENTER, 24, 14, UI.TEXT)
		return
	var outline := PackedVector2Array([Vector2(8,8), Vector2(16,2), Vector2(39,2), Vector2(47,10), Vector2(45,47), Vector2(9,47), Vector2(6,38), Vector2(8,8)])
	for i in range(outline.size()): outline[i] += offset
	draw_colored_polygon(outline, paper)
	draw_polyline(outline, Color.BLACK, 3, true)
	draw_line(Vector2(12,40)+offset, Vector2(40,40)+offset, Color("a4977d"), 2)
	draw_line(Vector2(14,10)+offset, Vector2(20,6)+offset, Color("a4977d"), 2)
	draw_string(UI.font(600), Vector2(11,33)+offset, str(number), HORIZONTAL_ALIGNMENT_CENTER, 30, 18, UI.TEXT)
