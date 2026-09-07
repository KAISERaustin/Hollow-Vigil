extends RefCounted
## Passive, fixed-width symbols for choices without a content actor.
const UI = preload("res://scripts/ui/shared/interface.gd")

static func preview(kind: String) -> Control:
	var art := Control.new()
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func(): draw(art, kind))
	return art

static func draw(art: Control, kind: String) -> void:
	var frame := Rect2(12, 10, 40, 44)
	art.draw_style_box(UI.surface(UI.SURFACE, 2, 4), frame)
	match kind:
		"slots":
			art.draw_rect(Rect2(20, 11, 24, 13), UI.MUTED)
			art.draw_rect(Rect2(35, 12, 5, 10), UI.PANEL)
			art.draw_rect(Rect2(20, 32, 24, 21), UI.PANEL)
			for y in [38, 44]: art.draw_line(Vector2(24, y), Vector2(40, y), UI.MUTED, 2)
		"levels":
			var route := PackedVector2Array([Vector2(20, 44), Vector2(42, 32), Vector2(24, 20)])
			art.draw_polyline(route, UI.TEXT, 2)
			for point in route:
				art.draw_circle(point, 5, UI.TEXT)
				art.draw_circle(point, 3, UI.GOLD)
		_:
			for y in [19, 27, 35, 43]: art.draw_line(Vector2(20, y), Vector2(44, y), UI.MUTED, 2)
