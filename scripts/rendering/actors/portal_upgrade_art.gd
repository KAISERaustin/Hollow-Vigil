extends RefCounted

const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")

# One construction kit for every portal. All measurements are local map units;
# no animation, texture scaling, input geometry or simulation state is involved.
static func structure(c: CanvasItem, style: String, at: Vector2, zoom: float, parts: Array) -> void:
	var z := Vector2.ONE * zoom
	var stone := Art.ground_color(style).lightened(0.18)
	if style == "core": stone = Art.PAPER
	var dark := Art.ground_color(style).darkened(0.30)
	var w := 2.3 * zoom
	if "foundation" in parts:
		Art.shape(c, [Vector2(-37,16),Vector2(37,16),Vector2(33,27),Vector2(-33,27)], at,z,stone,w)
		c.draw_line(at+Vector2(-30,22)*z,at+Vector2(30,22)*z,Art.INK,1.4*zoom,true)
	for side in [-1, 1]:
		var mirror := Vector2(side, 1) * z
		if "feet" in parts:
			Art.shape(c,[Vector2(27,12),Vector2(38,9),Vector2(45,22),Vector2(35,27)],at,mirror,dark,w)
		if "buttresses" in parts:
			Art.shape(c,[Vector2(26,15),Vector2(31,-17),Vector2(38,-22),Vector2(39,16)],at,mirror,stone,w)
			c.draw_line(at+Vector2(side*34,-9)*z,at+Vector2(side*34,11)*z,Art.PAPER,2*zoom,true)
		if "pillars" in parts:
			Art.shape(c,[Vector2(30,-12),Vector2(30,-39),Vector2(34,-48),Vector2(39,-39),Vector2(39,-12)],at,mirror,dark,w)
			Art.shape(c,[Vector2(28,-23),Vector2(41,-23),Vector2(41,-18),Vector2(28,-18)],at,mirror,stone,w)
		if "finials" in parts:
			Art.shape(c,[Vector2(30,-46),Vector2(34,-63),Vector2(40,-46),Vector2(35,-40)],at,mirror,Art.GOLD,w)
	if "lintel" in parts:
		Art.shape(c,[Vector2(-39,-40),Vector2(-33,-51),Vector2(-13,-51),Vector2(0,-59),Vector2(13,-51),Vector2(33,-51),Vector2(39,-40),Vector2(16,-40),Vector2(0,-47),Vector2(-16,-40)],at,z,stone,w)
		c.draw_line(at+Vector2(-28,-46)*z,at+Vector2(-14,-46)*z,Art.INK,1.5*zoom,true)
		c.draw_line(at+Vector2(14,-46)*z,at+Vector2(28,-46)*z,Art.INK,1.5*zoom,true)

static func details(c: CanvasItem, at: Vector2, zoom: float, parts: Dictionary) -> void:
	var z := Vector2.ONE * zoom
	# Six additional inlaid stones distinguish rate levels 7 through 12.
	# Alternating sides keeps the growing construction balanced around its crest.
	var sockets := [Vector2(-11,22),Vector2(11,22),Vector2(-22,22),Vector2(22,22),Vector2(-32,-33),Vector2(32,-33)]
	for i in range(mini(int(parts.runes), sockets.size())):
		Art.shape(c,[Vector2(0,-4),Vector2(3,0),Vector2(0,4),Vector2(-3,0)],at+sockets[i]*z,z,Art.GOLD,1.3*zoom)
	for part in parts.ornaments:
		var mount: Vector2 = part.at
		# A short iron bracket attaches the ornament to the masonry.
		if mount.x != 0:
			c.draw_line(at+Vector2(signf(mount.x)*22,mount.y-9)*z,at+(mount+Vector2(0,-9))*z,Art.INK,3*zoom,true)
		ornament(c, str(part.motif), at+mount*z, zoom, Color(part.color))

static func ornament(c: CanvasItem, motif: String, at: Vector2, zoom: float, color: Color) -> void:
	var z := Vector2.ONE * zoom
	var w := 1.8 * zoom
	match motif:
		"leaf":
			Art.shape(c,[Vector2(0,-9),Vector2(7,-3),Vector2(4,5),Vector2(0,8),Vector2(-6,3),Vector2(-7,-3)],at,z,color,w)
			c.draw_line(at+Vector2(0,-4)*z,at+Vector2(0,5)*z,Art.INK,1.3*zoom,true)
		"thorns":
			Art.shape(c,[Vector2(-2,9),Vector2(-5,1),Vector2(-11,-5),Vector2(-10,-13),Vector2(-5,-7),Vector2(-1,-4),Vector2(3,-11),Vector2(4,-5),Vector2(11,-9),Vector2(7,0),Vector2(3,4),Vector2(2,9)],at,z,color,w)
		"roots":
			Art.shape(c,[Vector2(-7,-10),Vector2(6,-10),Vector2(7,1),Vector2(12,10),Vector2(4,7),Vector2(0,12),Vector2(-3,6),Vector2(-11,9),Vector2(-6,0)],at,z,color,w)
			Art.shape(c,[Vector2(0,-6),Vector2(3,-2),Vector2(0,2),Vector2(-3,-2)],at,z,Art.GOLD,zoom)
		"ember":
			Art.shape(c,[Vector2(-9,-8),Vector2(-3,-5),Vector2(0,-10),Vector2(3,-5),Vector2(9,-8),Vector2(6,5),Vector2(-6,5)],at,z,Color("554943"),w)
			Art.shape(c,[Vector2(0,-5),Vector2(4,1),Vector2(0,5),Vector2(-4,1)],at,z,color,zoom)
		"lantern":
			c.draw_arc(at+Vector2(0,-9)*z,4*zoom,PI,TAU,10,Art.INK,w,true)
			Art.shape(c,[Vector2(-7,-8),Vector2(7,-8),Vector2(6,6),Vector2(0,11),Vector2(-6,6)],at,z,color,w)
			Art.shape(c,[Vector2(0,-4),Vector2(3,2),Vector2(0,6),Vector2(-3,2)],at,z,Art.INK,0)
		"anvil":
			Art.shape(c,[Vector2(-12,-9),Vector2(12,-9),Vector2(7,-3),Vector2(3,-3),Vector2(3,4),Vector2(8,8),Vector2(-8,8),Vector2(-3,4),Vector2(-3,-3),Vector2(-8,-3)],at,z,color,w)
			c.draw_line(at+Vector2(-7,-6)*z,at+Vector2(7,-6)*z,Art.CORAL,2*zoom,true)
		"reeds":
			for side in [-1,1]:
				Art.shape(c,[Vector2(side*2,8),Vector2(side*3,-3),Vector2(side*8,-10),Vector2(side*7,-1)],at,z,color,w)
			c.draw_line(at+Vector2(0,8)*z,at+Vector2(0,-8)*z,Art.INK,w,true)
		"shell":
			Art.shape(c,[Vector2(0,-11),Vector2(8,-5),Vector2(7,4),Vector2(0,10),Vector2(-7,4),Vector2(-8,-5)],at,z,color,w)
			for x in [-4,0,4]:
				c.draw_line(at+Vector2(x,-4)*z,at+Vector2(0,6)*z,Color("7fa6aa"),1.4*zoom,true)
		"bell":
			c.draw_arc(at+Vector2(0,-9)*z,3*zoom,PI,TAU,10,Art.INK,w,true)
			Art.disk(c,at+Vector2(0,10)*z,2.5*zoom,Art.GOLD,zoom)
			Art.shape(c,[Vector2(-4,-9),Vector2(4,-9),Vector2(7,-5),Vector2(8,3),Vector2(11,7),Vector2(11,9),Vector2(-11,9),Vector2(-11,7),Vector2(-8,3),Vector2(-7,-5)],at,z,color,w)
			c.draw_line(at+Vector2(-6,4)*z,at+Vector2(6,4)*z,Art.INK,1.4*zoom,true)
		"crescent", "ribbons":
			if motif == "ribbons":
				for side in [-1,1]:
					Art.shape(c,[Vector2(side*2,3),Vector2(side*7,1),Vector2(side*7,8),Vector2(side*12,13),Vector2(side*5,11)],at,z,Color("ae879b"),w)
			Art.shape(c,[Vector2(5,-10),Vector2(-3,-10),Vector2(-9,-4),Vector2(-8,3),Vector2(-2,8),Vector2(6,5),Vector2(0,4),Vector2(-3,0),Vector2(-3,-4)],at,z,color,w)
		"sword":
			Art.shape(c,[Vector2(0,-15),Vector2(4,-7),Vector2(2,4),Vector2(-2,4),Vector2(-4,-7)],at,z,Art.PAPER,w)
			c.draw_line(at+Vector2(0,3)*z,at+Vector2(0,11)*z,Art.INK,3*zoom,true)
			Art.shape(c,[Vector2(-9,0),Vector2(-4,2),Vector2(4,2),Vector2(9,0),Vector2(7,6),Vector2(-7,6)],at,z,color,w)
		"shroud", "veil":
			Art.shape(c,[Vector2(0,-11),Vector2(7,-5),Vector2(6,3),Vector2(9,10),Vector2(2,7),Vector2(-3,11),Vector2(-8,8),Vector2(-6,0),Vector2(-7,-5)],at,z,color,w)
			c.draw_line(at+Vector2(-2,-5)*z,at+Vector2(1,4)*z,Art.PAPER,1.5*zoom,true)
		"shield":
			Art.shape(c,[Vector2(-8,-9),Vector2(8,-9),Vector2(7,4),Vector2(0,11),Vector2(-7,4)],at,z,color,w)
			Art.shape(c,[Vector2(0,-5),Vector2(3,0),Vector2(0,5),Vector2(-3,0)],at,z,Art.LILAC,zoom)
		"battlement":
			Art.shape(c,[Vector2(-11,8),Vector2(-11,-10),Vector2(-5,-10),Vector2(-5,-5),Vector2(-2,-5),Vector2(-2,-10),Vector2(3,-10),Vector2(3,-5),Vector2(6,-5),Vector2(6,-10),Vector2(11,-10),Vector2(11,8)],at,z,color,w)
			Art.shape(c,[Vector2(-3,7),Vector2(-3,0),Vector2(0,-3),Vector2(3,0),Vector2(3,7)],at,z,Art.INK,0)
		"coffin":
			Art.shape(c,[Vector2(-4,-12),Vector2(4,-12),Vector2(8,-6),Vector2(6,10),Vector2(-6,10),Vector2(-8,-6)],at,z,color,w)
			for side in [-1,1]:
				c.draw_line(at+Vector2(side*5,-8)*z,at+Vector2(-side*4,6)*z,Art.PAPER,2*zoom,true)
