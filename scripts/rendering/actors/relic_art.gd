extends RefCounted

const Relics = preload("res://scripts/gameplay/progression/relics.gd")

# Distinct silhouettes as well as colors identify equipment at map scale.
static func draw(canvas: CanvasItem, kind: String, center: Vector2, scale_value: float = 1.0) -> void:
	if not Relics.DEFINITIONS.has(kind):
		return
	var tint := Color(Relics.DEFINITIONS[kind].color)
	var s := scale_value
	canvas.draw_circle(center, 13 * s, Color("171e24"))
	canvas.draw_arc(center, 13 * s, 0, TAU, 32, tint, 1.8 * s, true)
	match kind:
		"warden":
			canvas.draw_line(center + Vector2(0, -8) * s, center + Vector2(0, 8) * s, tint, 2 * s, true)
			for side in [-1, 1]:
				canvas.draw_polyline(PackedVector2Array([center + Vector2(side * 7, -6) * s, center, center + Vector2(side * 6, 7) * s]), tint, 2 * s, true)
		"cindermaw":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5,-8)*s, center + Vector2(6,-5)*s, center + Vector2(2,2)*s, center + Vector2(-6,9)*s, center + Vector2(-1,0)*s]), tint)
		"bell":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-8,5)*s, center + Vector2(-5,1)*s, center + Vector2(-4,-6)*s, center + Vector2(4,-6)*s, center + Vector2(5,1)*s, center + Vector2(8,5)*s, center + Vector2(-8,5)*s]), tint, 2*s, true)
			canvas.draw_arc(center + Vector2(0,7)*s, 2*s, 0, PI, 12, tint, 2*s, true)
		"prior":
			canvas.draw_circle(center, 8*s, tint)
			canvas.draw_circle(center + Vector2(4,-3)*s, 7*s, Color("171e24"))
			canvas.draw_line(center + Vector2(6,4)*s, center + Vector2(6,9)*s, tint, 2*s, true)
