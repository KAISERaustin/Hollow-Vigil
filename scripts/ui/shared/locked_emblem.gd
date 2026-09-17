extends Control
## Passive, reusable iron padlock. Progression remains owned by the destination.
const UI = preload("res://scripts/ui/shared/interface.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = "Locked"

func _draw() -> void:
	# Broad angular shackle and a shield-shaped aged-metal lock plate.
	var shackle := PackedVector2Array([Vector2(9,17), Vector2(9,8), Vector2(14,3), Vector2(22,3), Vector2(27,8), Vector2(27,17), Vector2(22,17), Vector2(22,10), Vector2(20,8), Vector2(16,8), Vector2(14,10), Vector2(14,17), Vector2(9,17)])
	draw_colored_polygon(shackle, UI.TEXT)
	draw_polyline(shackle, UI.BORDER, UI.OUTLINE, true)
	var plate := PackedVector2Array([Vector2(5,15), Vector2(31,15), Vector2(31,31), Vector2(18,39), Vector2(5,31), Vector2(5,15)])
	draw_colored_polygon(plate, UI.GOLD)
	draw_polyline(plate, UI.BORDER, UI.OUTLINE, true)
	draw_line(Vector2(8,18), Vector2(28,18), UI.TEXT, 1, true)
	for at in [Vector2(9,22), Vector2(27,22)]:
		draw_circle(at, 1.5, UI.ON_PRIMARY)
	draw_circle(Vector2(18,24), 3.5, UI.ON_PRIMARY)
	draw_colored_polygon(PackedVector2Array([Vector2(16,26), Vector2(20,26), Vector2(21,32), Vector2(15,32)]), UI.ON_PRIMARY)
