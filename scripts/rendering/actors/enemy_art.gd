class_name VigilEnemyArt
extends RefCounted

# Compact native silhouettes share the terrain/tower palette and ink strokes.
# All details stay inside x +/-18, y -19..12 for roads.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")

static func draw(canvas: CanvasItem, kind: String, at: Vector2, zoom: float) -> void:
	var z := Vector2.ONE * zoom
	var w := 1.8 * zoom
	match kind:
		"shade":
			Art.shape(canvas, [Vector2(-10,-8),Vector2(0,-19),Vector2(9,-10),Vector2(6,0),Vector2(12,10),Vector2(2,7),Vector2(-3,12),Vector2(-7,5),Vector2(-14,8)], at,z,Color("554664"),w)
			Art.shape(canvas, [Vector2(-6,-8),Vector2(0,-14),Vector2(5,-8),Vector2(3,-2),Vector2(-4,-2)],at,z,Color("171821"),zoom)
			for x in [-3,2]:
				canvas.draw_circle(at+Vector2(x,-7)*z,1.3*zoom,Art.LILAC)
			canvas.draw_line(at+Vector2(-5,1)*z,at+Vector2(-2,6)*z,Art.LILAC,1.4*zoom,true)
		"sentinel":
			Art.shape(canvas,[Vector2(-12,-8),Vector2(-5,-11),Vector2(6,-11),Vector2(13,-7),Vector2(10,5),Vector2(8,11),Vector2(2,11),Vector2(0,6),Vector2(-2,11),Vector2(-9,11)],at,z,Color("454958"),w)
			Art.shape(canvas,[Vector2(-8,-9),Vector2(-7,-18),Vector2(6,-18),Vector2(8,-9),Vector2(4,-4),Vector2(-4,-4)],at,z,Color("74798c"),w)
			canvas.draw_line(at+Vector2(-4,-11)*z,at+Vector2(4,-11)*z,Art.LILAC,2*zoom,true)
			Art.shape(canvas,[Vector2(-16,-6),Vector2(-8,-7),Vector2(-7,4),Vector2(-12,8),Vector2(-17,3)],at,z,Color("74798c"),w)
			Art.shape(canvas,[Vector2(2,-2),Vector2(5,1),Vector2(2,5),Vector2(-1,1)],at,z,Art.LILAC,zoom)
		"basic":
			# Frayed burial cloth, bone mask, and a single broken brow.
			Art.shape(canvas, [Vector2(-7,-5),Vector2(7,-5),Vector2(10,10),Vector2(3,8),Vector2(0,12),Vector2(-4,8),Vector2(-10,10)], at,z,Art.PAPER,w)
			Art.shape(canvas, [Vector2(-8,-9),Vector2(-4,-15),Vector2(5,-14),Vector2(9,-8),Vector2(6,0),Vector2(-5,0)], at,z,Art.PAPER,w)
			canvas.draw_polyline(PackedVector2Array([at+Vector2(1,-14)*z,at+Vector2(-1,-10)*z,at+Vector2(2,-8)*z]),Art.INK,zoom,true)
			for x in [-3, 4]:
				canvas.draw_circle(at+Vector2(x,-6)*z,1.7*zoom,Art.INK)
			canvas.draw_line(at+Vector2(-5,2)*z,at+Vector2(5,2)*z,Art.INK,1.5*zoom,true)
			canvas.draw_line(at+Vector2(-2,5)*z,at+Vector2(-3,8)*z,Art.INK,zoom,true)
		"fast":
			# Leaning cowl and forked spectral tails read as speed at map scale.
			Art.shape(canvas, [Vector2(-6,-7),Vector2(7,-8),Vector2(11,0),Vector2(4,5),Vector2(7,11),Vector2(-2,7),Vector2(-8,11),Vector2(-6,3),Vector2(-13,5),Vector2(-9,-1)], at,z,Art.MINT,w)
			Art.shape(canvas, [Vector2(-9,-6),Vector2(-4,-14),Vector2(8,-18),Vector2(6,-12),Vector2(10,-5),Vector2(5,0),Vector2(-5,-1)], at,z,Art.MINT,w)
			Art.shape(canvas, [Vector2(-4,-8),Vector2(4,-10),Vector2(6,-5),Vector2(1,-2),Vector2(-5,-4)], at,z,Art.INK,zoom)
			for x in [-2, 3]:
				canvas.draw_line(at+Vector2(x,-6)*z,at+Vector2(x+1,-6.5)*z,Art.PAPER,1.6*zoom,true)
			canvas.draw_line(at+Vector2(-2,2)*z,at+Vector2(1,5)*z,Art.INK,zoom,true)
		"heavy":
			# Broad pauldrons, horned helm, iron skirt, and a hot chest fissure.
			Art.shape(canvas, [Vector2(-9,1),Vector2(9,1),Vector2(10,11),Vector2(2,11),Vector2(0,7),Vector2(-2,11),Vector2(-10,11)], at,z,Art.CORAL,w)
			Art.shape(canvas, [Vector2(-10,-9),Vector2(10,-9),Vector2(11,5),Vector2(0,8),Vector2(-11,5)], at,z,Art.CORAL,w)
			for side in [-1,1]:
				Art.shape(canvas, [Vector2(side*7,-9),Vector2(side*13,-12),Vector2(side*16,-5),Vector2(side*10,-2)],at,z,Art.CORAL,w)
			Art.shape(canvas, [Vector2(-8,-10),Vector2(-9,-18),Vector2(-4,-15),Vector2(4,-15),Vector2(9,-18),Vector2(8,-10),Vector2(5,-5),Vector2(-5,-5)],at,z,Art.CORAL,w)
			canvas.draw_line(at+Vector2(-5,-10)*z,at+Vector2(5,-10)*z,Art.INK,3*zoom,true)
			for x in [-3,3]:
				canvas.draw_circle(at+Vector2(x,-10)*z,zoom,Art.GOLD)
			Art.shape(canvas,[Vector2(1,-4),Vector2(4,0),Vector2(0,5),Vector2(-3,1)],at,z,Art.GOLD,zoom)
		"lantern":
			# Pilgrim hood, split violet robe, bone clasp, and an offset lantern.
			Art.shape(canvas,[Vector2(-9,-5),Vector2(3,-5),Vector2(7,11),Vector2(-1,8),Vector2(-5,12),Vector2(-12,9)],at,z,Art.LILAC,w)
			Art.shape(canvas,[Vector2(-11,-7),Vector2(-9,-14),Vector2(-3,-19),Vector2(3,-14),Vector2(5,-7),Vector2(0,-3),Vector2(-7,-3)],at,z,Art.LILAC,w)
			Art.shape(canvas,[Vector2(-7,-10),Vector2(-3,-14),Vector2(1,-10),Vector2(0,-6),Vector2(-6,-6)],at,z,Art.INK,zoom)
			for x in [-5,-1]:
				canvas.draw_circle(at+Vector2(x,-9)*z,zoom,Art.PAPER)
			Art.disk(canvas,at+Vector2(-3,-2)*z,2*zoom,Art.PAPER,zoom)
			canvas.draw_line(at+Vector2(-3,2)*z,at+Vector2(-5,8)*z,Art.INK,zoom,true)
			canvas.draw_line(at+Vector2(3,-3)*z,at+Vector2(12,-5)*z,Art.INK,2*zoom,true)
			canvas.draw_arc(at+Vector2(12,-2)*z,3*zoom,PI,TAU,12,Art.INK,1.4*zoom,true)
			Art.shape(canvas,[Vector2(8,-2),Vector2(16,-2),Vector2(16,6),Vector2(12,9),Vector2(8,6)],at,z,Art.GOLD,1.5*zoom)
			Art.shape(canvas,[Vector2(12,0),Vector2(14,4),Vector2(12,6),Vector2(10,4)],at,z,Art.PAPER,zoom)
