extends RefCounted

# Native portraits and battlefield actors share these compact ink silhouettes.
# Shape helpers compose masks, robes and limbs; presentation never owns gameplay.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const COAL := Color("554943")
const FORGE := Color("bb8c76")
const WATER := Color("7fa6aa")
const BLOOD := Color("ae879b")

static func draw(c: CanvasItem, kind: String, at: Vector2, zoom: float) -> void:
	var z := Vector2.ONE * zoom
	var w := 1.8 * zoom
	match kind:
		"cinder_imp":
			# Splayed coal feet, pointed ears and an open furnace belly.
			for side in [-1, 1]:
				Art.shape(c,[Vector2(side*3,3),Vector2(side*8,3),Vector2(side*11,11),Vector2(side*2,10)],at,z,COAL,w)
				Art.shape(c,[Vector2(side*6,-6),Vector2(side*15,-10),Vector2(side*12,0),Vector2(side*7,2)],at,z,FORGE,w)
			Art.shape(c,[Vector2(-8,-6),Vector2(8,-6),Vector2(9,4),Vector2(0,8),Vector2(-9,4)],at,z,COAL,w)
			Art.shape(c,[Vector2(-8,-8),Vector2(-10,-18),Vector2(-3,-14),Vector2(3,-14),Vector2(10,-18),Vector2(8,-8),Vector2(0,-4)],at,z,FORGE,w)
			eyes(c,at+Vector2(0,-10)*z,zoom,Art.GOLD)
			Art.shape(c,[Vector2(0,-3),Vector2(4,2),Vector2(0,5),Vector2(-4,2)],at,z,Art.CORAL,zoom)
			c.draw_line(at+Vector2(0,0)*z,at+Vector2(0,3)*z,Art.PAPER,1.3*zoom,true)
		"slag_golem":
			legs(c,at,z,COAL,w)
			for side in [-1, 1]:
				Art.shape(c,[Vector2(side*8,-8),Vector2(side*16,-6),Vector2(side*18,5),Vector2(side*10,7)],at,z,FORGE,w)
			Art.shape(c,[Vector2(-10,-10),Vector2(10,-10),Vector2(11,5),Vector2(0,8),Vector2(-11,5)],at,z,COAL,w)
			Art.shape(c,[Vector2(-15,-18),Vector2(15,-18),Vector2(10,-12),Vector2(5,-12),Vector2(5,-6),Vector2(-5,-6),Vector2(-5,-12),Vector2(-11,-12)],at,z,FORGE,w)
			eyes(c,at+Vector2(0,-10)*z,zoom,Art.GOLD)
			c.draw_polyline(PackedVector2Array([at+Vector2(-5,-4)*z,at+Vector2(2,0)*z,at+Vector2(-1,5)*z]),Art.CORAL,2.5*zoom,true)
		"drowned_thrall":
			robe(c,at,z,WATER,w)
			Art.shape(c,[Vector2(-8,-12),Vector2(-3,-17),Vector2(5,-16),Vector2(9,-10),Vector2(5,-3),Vector2(-5,-3)],at,z,Art.PAPER,w)
			eyes(c,at+Vector2(0,-9)*z,zoom,Art.INK)
			for side in [-1, 1]:
				c.draw_polyline(PackedVector2Array([at+Vector2(side*6,-12)*z,at+Vector2(side*10,-5)*z,at+Vector2(side*8,4)*z,at+Vector2(side*13,9)*z]),Color("557d77"),2.5*zoom,true)
			c.draw_line(at+Vector2(-4,2)*z,at+Vector2(4,4)*z,Art.INK,zoom,true)
		"mire_wraith":
			Art.shape(c,[Vector2(-5,-7),Vector2(5,-9),Vector2(12,-2),Vector2(5,3),Vector2(12,11),Vector2(2,7),Vector2(0,12),Vector2(-5,5),Vector2(-14,8),Vector2(-8,0),Vector2(-14,-4)],at,z,WATER,w)
			Art.shape(c,[Vector2(-7,-8),Vector2(-7,-15),Vector2(0,-19),Vector2(7,-14),Vector2(7,-8),Vector2(0,-2)],at,z,Art.PAPER,w)
			c.draw_line(at+Vector2(0,-15)*z,at+Vector2(0,-5)*z,Art.INK,zoom,true)
			eyes(c,at+Vector2(0,-10)*z,zoom,Art.INK)
			c.draw_polyline(PackedVector2Array([at+Vector2(-4,0)*z,at+Vector2(0,3)*z,at+Vector2(6,6)*z]),Art.MINT,2*zoom,true)
		"bell_hulk":
			legs(c,at,z,WATER,w)
			for side in [-1, 1]:
				Art.shape(c,[Vector2(side*9,-6),Vector2(side*15,-4),Vector2(side*17,6),Vector2(side*11,7)],at,z,WATER,w)
			c.draw_arc(at+Vector2(0,-15)*z,3*zoom,PI,TAU,12,Art.INK,2*zoom,true)
			Art.shape(c,[Vector2(-6,-15),Vector2(6,-15),Vector2(10,-10),Vector2(12,2),Vector2(15,5),Vector2(15,8),Vector2(-15,8),Vector2(-15,5),Vector2(-12,2),Vector2(-10,-10)],at,z,Color("96966f"),w)
			c.draw_line(at+Vector2(-8,-4)*z,at+Vector2(8,-4)*z,Art.INK,2.5*zoom,true)
			eyes(c,at+Vector2(0,-4)*z,zoom,Art.MINT)
			c.draw_line(at+Vector2(-9,3)*z,at+Vector2(9,3)*z,Art.INK,zoom,true)
			Art.disk(c,at+Vector2(0,9)*z,2*zoom,COAL,zoom)
		"blood_acolyte":
			robe(c,at,z,BLOOD,w)
			Art.shape(c,[Vector2(-8,-7),Vector2(0,-19),Vector2(8,-7),Vector2(5,-2),Vector2(-5,-2)],at,z,Color("765063"),w)
			Art.shape(c,[Vector2(-4,-8),Vector2(0,-12),Vector2(4,-8),Vector2(0,-4)],at,z,Art.PAPER,zoom)
			c.draw_line(at+Vector2(0,-8)*z,at+Vector2(0,-6)*z,Art.INK,zoom,true)
			c.draw_line(at+Vector2(13,-10)*z,at+Vector2(13,11)*z,Art.INK,2*zoom,true)
			c.draw_arc(at+Vector2(13,-13)*z,4*zoom,0.0,PI*1.6,16,Art.INK,4*zoom,true)
			c.draw_arc(at+Vector2(13,-13)*z,4*zoom,0.0,PI*1.6,16,Art.PAPER,2*zoom,true)
			c.draw_line(at+Vector2(-3,1)*z,at+Vector2(2,7)*z,Art.PAPER,1.5*zoom,true)
		"crescent_wisp":
			for side in [-1, 1]:
				Art.shape(c,[Vector2(side*3,-1),Vector2(side*7,-2),Vector2(side*8,5),Vector2(side*15,10),Vector2(side*8,11),Vector2(side*3,5)],at,z,BLOOD,w)
			Art.shape(c,[Vector2(0,0),Vector2(4,3),Vector2(1,12),Vector2(-4,8)],at,z,Art.PAPER,w)
			# A crescent open on the right, enclosing a dark veiled eye.
			Art.shape(c,[Vector2(6,-18),Vector2(-3,-18),Vector2(-10,-12),Vector2(-11,-5),Vector2(-6,1),Vector2(2,3),Vector2(8,0),Vector2(0,-1),Vector2(-4,-6),Vector2(-3,-12)],at,z,Art.PAPER,w)
			Art.shape(c,[Vector2(0,-11),Vector2(8,-8),Vector2(4,-2),Vector2(-1,-4)],at,z,Color("765063"),zoom)
			c.draw_circle(at+Vector2(3,-7)*z,2*zoom,Art.CORAL)

static func eyes(c: CanvasItem, at: Vector2, zoom: float, color: Color) -> void:
	for side in [-1, 1]:
		c.draw_circle(at+Vector2(side*3,0)*zoom,1.3*zoom,color)

static func legs(c: CanvasItem, at: Vector2, z: Vector2, color: Color, w: float) -> void:
	for side in [-1, 1]:
		Art.shape(c,[Vector2(side*2,3),Vector2(side*9,3),Vector2(side*12,12),Vector2(side*3,12)],at,z,color,w)

static func robe(c: CanvasItem, at: Vector2, z: Vector2, color: Color, w: float) -> void:
	Art.shape(c,[Vector2(-7,-6),Vector2(7,-6),Vector2(11,11),Vector2(4,9),Vector2(0,12),Vector2(-4,9),Vector2(-11,11)],at,z,color,w)
