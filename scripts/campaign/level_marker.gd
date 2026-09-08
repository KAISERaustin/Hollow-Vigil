extends Button

const UI = preload("res://scripts/ui/shared/interface.gd")
const ClearedArt = preload("res://scripts/campaign/cleared_level_art.gd")
var number := 1
var completed := false
var current := false
var gate: Texture2D
var gate_style := ""
var landmark_kind := ""
var landscape_profile: Dictionary = {}

func is_gate() -> bool:
	return gate != null or not gate_style.is_empty()

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _draw() -> void:
	var active := not disabled and has_focus()
	var paper := UI.GOLD if active or current else Color("e8ddbd")
	var offset := Vector2(0, 2) if button_pressed else Vector2.ZERO
	if current:
		# A persistent pointer distinguishes progress from transient keyboard focus.
		var center := size.x * 0.5
		var pointer := PackedVector2Array([Vector2(center-8,0), Vector2(center+8,0), Vector2(center,10), Vector2(center-8,0)])
		draw_colored_polygon(pointer, UI.GOLD)
		draw_polyline(pointer, Color.BLACK, 2, true)
	if completed:
		if active:
			draw_style_box(UI.surface(Color(0,0,0,0), UI.OUTLINE, 4), Rect2(Vector2.ZERO, size))
		var rubble_offset := Vector2.ZERO if is_gate() else (size-Vector2(54,54))*0.5
		ClearedArt.draw(self, offset+rubble_offset, is_gate())
		if is_gate():
			var plaque := Rect2(size.x * 0.5 - 18, size.y - 21, 36, 22)
			draw_style_box(UI.surface(paper, UI.OUTLINE, 4), plaque)
			draw_string(UI.font(600), plaque.position + Vector2(6, 16), str(number), HORIZONTAL_ALIGNMENT_CENTER, 24, 14, UI.TEXT)
		else:
			draw_string(UI.font(600), Vector2(9,40)+offset+rubble_offset, str(number), HORIZONTAL_ALIGNMENT_CENTER, 26, 16, UI.TEXT)
		return
	if is_gate():
		if not gate_style.is_empty():
			var at := Vector2(size.x*0.5,69)+offset
			var zoom := 0.84
			var kit = preload("res://scripts/rendering/actors/portal_upgrade_art.gd")
			kit.structure(self,gate_style,at,zoom,["foundation","buttresses","pillars","lintel","finials"])
			preload("res://scripts/rendering/actors/rift_art.gd").draw_base(self,gate_style,at,zoom)
		elif gate != null:
			draw_texture_rect(gate, Rect2(Vector2.ZERO, size), false)
		var plaque := Rect2(size.x * 0.5 - 18, size.y - 21, 36, 22)
		draw_style_box(UI.surface(paper, UI.OUTLINE, 4), plaque)
		draw_string(UI.font(600), plaque.position + Vector2(6, 16), str(number), HORIZONTAL_ALIGNMENT_CENTER, 24, 14, UI.TEXT)
		return
	if not landmark_kind.is_empty():
		preload("res://scripts/rendering/terrain/map_landmark_art.gd").draw(self,landmark_kind,Rect2(offset,Vector2(size.x,size.x*0.9)),landscape_profile)
		var plaque := Rect2(size.x*0.5-19,size.y-29,38,26)
		draw_style_box(UI.surface(paper,UI.OUTLINE,4),plaque)
		draw_string(UI.font(600),plaque.position+Vector2(4,19),str(number),HORIZONTAL_ALIGNMENT_CENTER,30,17,UI.TEXT)
		return
	var outline := PackedVector2Array([Vector2(8,8), Vector2(16,2), Vector2(39,2), Vector2(47,10), Vector2(45,47), Vector2(9,47), Vector2(6,38), Vector2(8,8)])
	for i in range(outline.size()): outline[i] += offset
	draw_colored_polygon(outline, paper)
	draw_polyline(outline, Color.BLACK, 3, true)
	draw_line(Vector2(12,40)+offset, Vector2(40,40)+offset, Color("a4977d"), 2)
	draw_line(Vector2(14,10)+offset, Vector2(20,6)+offset, Color("a4977d"), 2)
	draw_string(UI.font(600), Vector2(11,33)+offset, str(number), HORIZONTAL_ALIGNMENT_CENTER, 30, 18, UI.TEXT)
