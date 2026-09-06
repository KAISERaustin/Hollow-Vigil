extends RefCounted

# Mourning Orchard: ivory roots, olive earth, dusty veils and dark seed pods.
# Native geometry stays crisp at every camera scale and matches existing art.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const ROOT := Color("d8cead")
const BARK := Color("777c55")
const VEIL := Color("c4b6b1")
const EARTH := Color("a5aa73")

static func scenery(canvas: CanvasItem, at: Vector2, extent: float) -> void:
	var z := Vector2.ONE * extent / 30.0
	# Crooked leafless tree with two hanging seed urns; reserve the tower sockets.
	Art.shape(canvas, [Vector2(-9,12),Vector2(-3,5),Vector2(-4,-6),Vector2(-11,-12),Vector2(-12,-18),Vector2(-8,-13),Vector2(-3,-10),Vector2(-1,-21),Vector2(2,-13),Vector2(9,-18),Vector2(7,-10),Vector2(2,-6),Vector2(3,5),Vector2(10,12),Vector2(2,10),Vector2(0,6),Vector2(-2,11)], at,z,ROOT,1.8)
	for p in [Vector2(-9,-6), Vector2(7,-4)]:
		canvas.draw_line(at+(p+Vector2(0,-7))*z,at+p*z,Art.INK,1.0,true)
		Art.shape(canvas,[Vector2(-3,-2),Vector2(3,-2),Vector2(4,2),Vector2(0,5),Vector2(-4,2)],at+p*z,z,BARK,1.2)
		canvas.draw_line(at+(p+Vector2(-1,0))*z,at+(p+Vector2(1,0))*z,ROOT,1.0,true)

static func detail(canvas: CanvasItem, at: Vector2, variant: int, scale_value: float) -> void:
	var z := Vector2.ONE * scale_value
	if variant % 3 == 0:
		Art.shape(canvas,[Vector2(-4,-3),Vector2(1,-4),Vector2(0,0),Vector2(5,-1),Vector2(3,4),Vector2(-3,3)],at,z,ROOT,1.0)
		canvas.draw_line(at+Vector2(-2,-1)*z,at+Vector2(1,2)*z,BARK,1.0,true)
	else:
		canvas.draw_polyline(PackedVector2Array([at+Vector2(-7,3)*z,at+Vector2(-2,0)*z,at+Vector2(3,1)*z,at+Vector2(7,-3)*z]),BARK,1.3,true)
		canvas.draw_line(at+Vector2(-2,0)*z,at+Vector2(-3,-4)*z,BARK,1.3,true)
		canvas.draw_line(at+Vector2(3,1)*z,at+Vector2(5,4)*z,BARK,1.3,true)

static func portal(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	var z := Vector2.ONE * zoom
	var w := 2.5 * zoom
	Art.ellipse(canvas,at+Vector2(0,15)*z,Vector2(31,8)*z,Art.INK,0)
	Art.shape(canvas,[Vector2(-25,12),Vector2(-23,-18),Vector2(-11,-35),Vector2(0,-42),Vector2(11,-35),Vector2(23,-18),Vector2(25,12)],at,z,BARK,w)
	Art.shape(canvas,[Vector2(-14,10),Vector2(-13,-17),Vector2(0,-31),Vector2(13,-17),Vector2(14,10)],at,z,Art.INK,w)
	for side in [-1,1]:
		Art.shape(canvas,[Vector2(side*28,14),Vector2(side*18,4),Vector2(side*19,-16),Vector2(side*11,-29),Vector2(side*12,-42),Vector2(side*17,-30),Vector2(side*28,-34),Vector2(side*23,-25),Vector2(side*25,-12),Vector2(side*22,5),Vector2(side*32,12)],at,z,ROOT,1.8*zoom)
		canvas.draw_line(at+Vector2(side*22,-23)*z,at+Vector2(side*21,-9)*z,Art.INK,1.2*zoom,true)
		Art.disk(canvas,at+Vector2(side*21,-7)*z,3*zoom,VEIL,1.2*zoom)
	# A hanging burial veil identifies the entrance at small map scales.
	Art.shape(canvas,[Vector2(0,-24),Vector2(6,-17),Vector2(5,-8),Vector2(8,3),Vector2(1,0),Vector2(-5,5),Vector2(-4,-9),Vector2(-6,-17)],at,z,VEIL,1.5*zoom)
	canvas.draw_line(at+Vector2(-2,-15)*z,at+Vector2(3,-15)*z,Art.INK,2*zoom,true)
	Art.shape(canvas,[Vector2(-27,12),Vector2(27,12),Vector2(24,18),Vector2(-24,18)],at,z,ROOT,w)

static func enemy(canvas: CanvasItem, kind: String, at: Vector2, zoom: float) -> void:
	var z := Vector2.ONE * zoom
	var w := 1.8 * zoom
	match kind:
		"briarling":
			# Narrow twig limbs, asymmetric antlers, a pale seed mask.
			Art.shape(canvas,[Vector2(-5,-3),Vector2(4,-4),Vector2(8,3),Vector2(12,5),Vector2(6,6),Vector2(2,2),Vector2(1,7),Vector2(6,11),Vector2(0,10),Vector2(-3,5),Vector2(-7,11),Vector2(-10,11),Vector2(-6,3),Vector2(-11,3),Vector2(-7,-1)],at,z,BARK,w)
			Art.shape(canvas,[Vector2(-7,-8),Vector2(-12,-13),Vector2(-11,-18),Vector2(-8,-13),Vector2(-3,-10),Vector2(2,-12),Vector2(6,-18),Vector2(7,-12),Vector2(11,-14),Vector2(8,-7)],at,z,ROOT,1.4*zoom)
			Art.shape(canvas,[Vector2(-6,-10),Vector2(3,-12),Vector2(7,-7),Vector2(3,-1),Vector2(-3,-1),Vector2(-7,-5)],at,z,ROOT,w)
			for x in [-3,3]:
				canvas.draw_circle(at+Vector2(x,-6)*z,1.4*zoom,Art.INK)
		"veil_widow":
			# Wide split veil and a dark oval face; no lantern or armored shoulders.
			Art.shape(canvas,[Vector2(0,-18),Vector2(9,-10),Vector2(8,-2),Vector2(15,9),Vector2(7,7),Vector2(4,12),Vector2(0,7),Vector2(-6,12),Vector2(-8,7),Vector2(-15,9),Vector2(-8,-3),Vector2(-9,-10)],at,z,VEIL,w)
			Art.ellipse(canvas,at+Vector2(0,-7)*z,Vector2(4,6)*z,Art.INK,zoom)
			canvas.draw_line(at+Vector2(-2,-8)*z,at+Vector2(2,-8)*z,ROOT,1.4*zoom,true)
			for side in [-1,1]:
				canvas.draw_line(at+Vector2(side*5,-1)*z,at+Vector2(side*9,6)*z,BARK,1.3*zoom,true)
			Art.shape(canvas,[Vector2(0,0),Vector2(3,3),Vector2(0,7),Vector2(-3,3)],at,z,ROOT,zoom)
		"coffinbound":
			# A coffin-shaped torso, root bindings, and separated heavy feet.
			for side in [-1,1]:
				Art.shape(canvas,[Vector2(side*3,5),Vector2(side*9,5),Vector2(side*12,11),Vector2(side*3,11)],at,z,BARK,w)
			Art.shape(canvas,[Vector2(-6,-18),Vector2(6,-18),Vector2(12,-9),Vector2(9,7),Vector2(-9,7),Vector2(-12,-9)],at,z,BARK,w)
			Art.shape(canvas,[Vector2(-4,-14),Vector2(4,-14),Vector2(8,-8),Vector2(6,3),Vector2(-6,3),Vector2(-8,-8)],at,z,EARTH,zoom)
			for side in [-1,1]:
				canvas.draw_polyline(PackedVector2Array([at+Vector2(side*6,-16)*z,at+Vector2(side*3,-8)*z,at+Vector2(side*10,-3)*z,at+Vector2(side*8,6)*z]),ROOT,2.5*zoom,true)
			canvas.draw_line(at+Vector2(-3,-8)*z,at+Vector2(3,-8)*z,Art.INK,2*zoom,true)
			canvas.draw_line(at+Vector2(0,-11)*z,at+Vector2(0,-4)*z,Art.INK,1.4*zoom,true)
