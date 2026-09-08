extends RefCounted
const UI = preload("res://scripts/ui/shared/interface.gd")

## Small visual lip with a full-height touch target.
static func create(action: Callable) -> Button:
	var button := UI.button("", action, UI.TARGET)
	button.accessibility_name = "Open tower drawer"
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, UI.plain())
	var lip := UI.surface(UI.PANEL, UI.OUTLINE, 0)
	lip.set_corner_radius_all(0)
	button.draw.connect(func():
		var y := button.size.y - 12.0
		button.draw_style_box(lip, Rect2(0, y, button.size.x, 12))
		var center := button.size.x * 0.5
		var points := PackedVector2Array([Vector2(center - 14, y), Vector2(center, y - 12), Vector2(center + 14, y)])
		button.draw_colored_polygon(points, UI.PANEL)
		button.draw_polyline(points, UI.BORDER, UI.OUTLINE, true)
	)
	return button
