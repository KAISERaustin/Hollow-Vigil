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
	match Relics.DEFINITIONS[kind].symbol:
		"root":
			canvas.draw_line(center + Vector2(0, -8) * s, center + Vector2(0, 8) * s, tint, 2 * s, true)
			for side in [-1, 1]:
				canvas.draw_polyline(PackedVector2Array([center + Vector2(side * 7, -6) * s, center, center + Vector2(side * 6, 7) * s]), tint, 2 * s, true)
		"fang":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5,-8)*s, center + Vector2(6,-5)*s, center + Vector2(2,2)*s, center + Vector2(-6,9)*s, center + Vector2(-1,0)*s]), tint)
		"bell":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-8,5)*s, center + Vector2(-5,1)*s, center + Vector2(-4,-6)*s, center + Vector2(4,-6)*s, center + Vector2(5,1)*s, center + Vector2(8,5)*s, center + Vector2(-8,5)*s]), tint, 2*s, true)
			canvas.draw_arc(center + Vector2(0,7)*s, 2*s, 0, PI, 12, tint, 2*s, true)
		"eclipse":
			canvas.draw_circle(center, 8*s, tint)
			canvas.draw_circle(center + Vector2(4,-3)*s, 7*s, Color("171e24"))
			canvas.draw_line(center + Vector2(6,4)*s, center + Vector2(6,9)*s, tint, 2*s, true)
		"spindle":
			stroke(canvas, center, s, [Vector2(-7, 8), Vector2(6, -8)], tint)
			for offset in [-4, 1, 6]:
				stroke(canvas, center, s, [Vector2(-offset, offset), Vector2(-offset - 4, offset - 5), Vector2(-offset + 3, offset - 2)], tint)
		"lens":
			canvas.draw_arc(center + Vector2(-2, -2) * s, 6 * s, 0, TAU, 24, tint, 2 * s, true)
			stroke(canvas, center, s, [Vector2(2, 3), Vector2(8, 9)], tint)
			stroke(canvas, center, s, [Vector2(-5, -2), Vector2(1, -2)], tint)
		"censer":
			stroke(canvas, center, s, [Vector2(0, -10), Vector2(-6, 3), Vector2(6, 3), Vector2(0, -10)], tint)
			shape(canvas, center, s, [Vector2(-8, 3), Vector2(8, 3), Vector2(4, 8), Vector2(-4, 8)], tint)
		"seal":
			shape(canvas, center, s, [Vector2(-7, -7), Vector2(7, -7), Vector2(6, 6), Vector2(0, 10), Vector2(-6, 6)], tint)
			stroke(canvas, center, s, [Vector2(-3, 3), Vector2(0, -4), Vector2(3, 3)], Color("171e24"))
		"chain":
			for offset in [-5, 0, 5]:
				canvas.draw_arc(center + Vector2(offset, -offset) * s, 4 * s, 0, TAU, 16, tint, 2 * s, true)
		"chime":
			stroke(canvas, center, s, [Vector2(-8, -7), Vector2(8, -7)], tint)
			for offset in [-5, 0, 5]:
				stroke(canvas, center, s, [Vector2(offset, -5), Vector2(offset, 8 - absi(offset))], tint)
		"rosary":
			for index in range(8):
				canvas.draw_circle(center + Vector2.from_angle(index * TAU / 8) * 6 * s, 1.8 * s, tint)
			stroke(canvas, center, s, [Vector2(0, 6), Vector2(0, 11)], tint)
		"mirror":
			shape(canvas, center, s, [Vector2(0, -10), Vector2(7, -3), Vector2(4, 6), Vector2(0, 9), Vector2(-5, 5), Vector2(-7, -4)], tint)
			stroke(canvas, center, s, [Vector2(1, -6), Vector2(-2, 0), Vector2(3, 3), Vector2(0, 6)], Color("171e24"))
		"crown":
			shape(canvas, center, s, [Vector2(-9, -5), Vector2(-4, 0), Vector2(0, -9), Vector2(4, 0), Vector2(9, -5), Vector2(7, 7), Vector2(-7, 7)], tint)
			stroke(canvas, center, s, [Vector2(-5, 4), Vector2(5, 4)], Color("171e24"))
		"signet":
			canvas.draw_arc(center + Vector2(0, 3) * s, 6 * s, 0, TAU, 24, tint, 2.5 * s, true)
			shape(canvas, center, s, [Vector2(-5, -8), Vector2(5, -8), Vector2(5, -1), Vector2(-5, -1)], tint)
			stroke(canvas, center, s, [Vector2(0, -6), Vector2(0, -3)], Color("171e24"))
		"blade":
			shape(canvas, center, s, [Vector2(2, -10), Vector2(6, -6), Vector2(0, 4), Vector2(-4, 1)], tint)
			stroke(canvas, center, s, [Vector2(-7, 0), Vector2(3, 6)], tint)
			stroke(canvas, center, s, [Vector2(-2, 3), Vector2(-6, 9)], tint)
		"veil":
			shape(canvas, center, s, [Vector2(-4, -9), Vector2(4, -9), Vector2(9, 9), Vector2(3, 6), Vector2(0, 9), Vector2(-3, 6), Vector2(-9, 9)], tint)
			stroke(canvas, center, s, [Vector2(-2, -5), Vector2(-4, 4)], Color("171e24"))
			stroke(canvas, center, s, [Vector2(2, -5), Vector2(4, 4)], Color("171e24"))
		"fruit":
			canvas.draw_circle(center + Vector2(-3, 2) * s, 6 * s, tint)
			canvas.draw_circle(center + Vector2(3, 2) * s, 6 * s, tint)
			stroke(canvas, center, s, [Vector2(0, -3), Vector2(1, -9), Vector2(6, -8)], tint)
			stroke(canvas, center, s, [Vector2(-4, 0), Vector2(-5, 3)], Color("171e24"))
		"lantern":
			canvas.draw_arc(center + Vector2(0, -6) * s, 3 * s, PI, TAU, 12, tint, 2 * s, true)
			stroke(canvas, center, s, [Vector2(-6, -4), Vector2(6, -4), Vector2(7, 7), Vector2(-7, 7), Vector2(-6, -4)], tint)
			shape(canvas, center, s, [Vector2(0, -2), Vector2(3, 3), Vector2(0, 5), Vector2(-3, 3)], tint)

static func stroke(canvas: CanvasItem, center: Vector2, scale_value: float, points: Array, color: Color) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(center + point * scale_value)
	canvas.draw_polyline(transformed, color, 2 * scale_value, true)

static func shape(canvas: CanvasItem, center: Vector2, scale_value: float, points: Array, color: Color) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(center + point * scale_value)
	canvas.draw_colored_polygon(transformed, color)
