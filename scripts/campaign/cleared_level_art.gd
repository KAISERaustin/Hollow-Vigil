extends RefCounted

# Shared completion presentation for ordinary levels and chapter gates.
# Stateless drawing: campaign progress remains the sole owner of completion.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")

static func shape(canvas: CanvasItem, points: Array, at: Vector2, fill: Color) -> void:
	Art.shape(canvas, points, at, Vector2.ONE, fill, 2.0)

static func beacon(canvas: CanvasItem, at: Vector2) -> void:
	shape(canvas, [Vector2(-2,0),Vector2(2,0),Vector2(3,-19),Vector2(-3,-19)], at, Color("a4977d"))
	shape(canvas, [Vector2(-5,-23),Vector2(-8,-29),Vector2(-4,-35),Vector2(-2,-44),Vector2(3,-38),Vector2(7,-31),Vector2(5,-23)], at, Art.GOLD)
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-2,-24),at+Vector2(-3,-29),at+Vector2(0,-35),at+Vector2(3,-28),at+Vector2(2,-24)]), Art.PAPER)
	shape(canvas, [Vector2(-8,-23),Vector2(8,-23),Vector2(5,-17),Vector2(-5,-17)], at, Color("a4977d"))

static func draw(canvas: CanvasItem, at: Vector2, gate: bool) -> void:
	if gate:
		# Broken jambs retain the gate silhouette, with an extinguished black opening.
		shape(canvas, [Vector2(6,95),Vector2(8,57),Vector2(17,48),Vector2(22,57),Vector2(28,53),Vector2(27,95)], at, Art.PAPER)
		shape(canvas, [Vector2(51,96),Vector2(52,68),Vector2(59,73),Vector2(64,63),Vector2(71,70),Vector2(74,96)], at, Art.PAPER)
		canvas.draw_line(at+Vector2(17,64),at+Vector2(16,89),Color("a4977d"),2)
		shape(canvas, [Vector2(23,91),Vector2(33,79),Vector2(49,84),Vector2(55,95)], at, Color("a4977d"))
		shape(canvas, [Vector2(2,97),Vector2(11,89),Vector2(20,94),Vector2(18,101),Vector2(5,103)], at, Art.PAPER)
		shape(canvas, [Vector2(58,96),Vector2(68,89),Vector2(78,97),Vector2(74,103)], at, Art.PAPER)
		beacon(canvas, at+Vector2(40,87))
	else:
		# A broken crown, cracked numbered slab and loose masonry replace the seal.
		shape(canvas, [Vector2(7,43),Vector2(10,20),Vector2(19,16),Vector2(24,23),Vector2(30,19),Vector2(35,25),Vector2(35,44)], at, Art.PAPER)
		canvas.draw_polyline(PackedVector2Array([at+Vector2(17,19),at+Vector2(19,26),at+Vector2(15,30)]),Color.BLACK,1.5,true)
		shape(canvas, [Vector2(4,48),Vector2(9,43),Vector2(18,46),Vector2(16,51),Vector2(6,51)], at, Color("a4977d"))
		shape(canvas, [Vector2(29,47),Vector2(35,42),Vector2(42,47),Vector2(39,51)], at, Art.PAPER)
		beacon(canvas, at+Vector2(44,46))
