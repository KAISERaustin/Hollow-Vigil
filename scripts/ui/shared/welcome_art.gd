extends Control
## Stateless full-bleed cover artwork and matching diamond ornament.
const UI = preload("res://scripts/ui/shared/interface.gd")
const PICKARD = preload("res://assets/ui/pickard-menu-background.png")
@export_enum("background", "rule") var illustration := "background"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if illustration == "background":
		var texture_size := PICKARD.get_size()
		var zoom := maxf(size.x / texture_size.x, size.y / texture_size.y)
		var region_size := size / zoom
		draw_texture_rect_region(PICKARD, Rect2(Vector2.ZERO, size), Rect2((texture_size - region_size) * 0.5, region_size))
		return
	var center := size * 0.5
	for side in [-1, 1]:
		draw_line(center + Vector2(side * 18, 0), center + Vector2(side * 52, 0), UI.PANEL, UI.OUTLINE)
	var points := PackedVector2Array([center + Vector2(0, -7), center + Vector2(4, 0), center + Vector2(0, 7), center + Vector2(-4, 0), center + Vector2(0, -7)])
	draw_polyline(points, UI.PANEL, UI.OUTLINE, true)
