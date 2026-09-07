extends RefCounted

const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const STONE := Color("bd8e78")
const SHADE := Color("88685c")
const IRON := Color("626671")
const CHAR := Color("494252")
const EMBER := Color("f19b57")
const PORTRAIT_BOUNDS := Rect2(-29, -64, 58, 78)

# One stateless masonry/flame kit for every Pyre tier and specialization.
# Keep the shared socket anchor and projectile outlet at (0, -29).
static func draw(c: CanvasItem, at: Vector2, zoom: float, level: int, branch: String = "") -> void:
	var tier := clampi(level, 1, 3)
	var cinder := level == 4 and branch == "cinderfield"
	var rupture := level == 4 and branch == "rupture_pyre"
	var z := Vector2.ONE * zoom
	var w := 2.5 * zoom
	var stone := CHAR if cinder else STONE
	var shade := IRON if rupture else SHADE
	var crown := IRON if rupture else Art.CORAL
	if cinder:
		shade = Color("342e35")
		crown = SHADE

	# Tall, weight-bearing ashlar shaft with a separate shaded side face.
	Art.shape(c, [Vector2(-17,6),Vector2(-14,-31),Vector2(14,-31),Vector2(17,6)], at,z,stone,w)
	Art.shape(c, [Vector2(8,-31),Vector2(14,-31),Vector2(17,6),Vector2(8,6)], at,z,shade,1.3*zoom)
	for y in [-20,-7]:
		c.draw_line(at+Vector2(-14,y)*z,at+Vector2(8,y)*z,Art.INK,1.2*zoom,true)
	c.draw_line(at+Vector2(-7,-30)*z,at+Vector2(-7,-20)*z,Art.INK,1.2*zoom,true)
	c.draw_line(at+Vector2(-9,-7)*z,at+Vector2(-9,5)*z,Art.INK,1.2*zoom,true)

	# Reinforcement grows around the same tower instead of replacing its body.
	if tier >= 2:
		for side in [-1,1]:
			Art.shape(c, [Vector2(side*13,5),Vector2(side*15,-19),Vector2(side*20,-15),Vector2(side*23,6)], at,z,shade,w)
			Art.shape(c, [Vector2(side*14,-19),Vector2(side*19,-19),Vector2(side*20,-14),Vector2(side*14,-14)], at,z,Art.PAPER,1.5*zoom)
		Art.shape(c, [Vector2(-17,-27),Vector2(17,-27),Vector2(16,-22),Vector2(-16,-22)], at,z,Art.PAPER,w)

	# A black arched furnace and inset flame borrow the portals' deep openings.
	Art.shape(c, [Vector2(-7,3),Vector2(-7,-12),Vector2(0,-19),Vector2(7,-12),Vector2(7,3)], at,z,Art.PAPER,1.8*zoom)
	Art.shape(c, [Vector2(-4,2),Vector2(-4,-11),Vector2(0,-15),Vector2(4,-11),Vector2(4,2)], at,z,Art.INK,0)
	flame(c, at+Vector2(0,1)*z, zoom*0.42, tier >= 2)
	Art.shape(c, [Vector2(-9,3),Vector2(9,3),Vector2(11,7),Vector2(-11,7)], at,z,shade,1.8*zoom)

	# Roof fire rises behind a real crenellated parapet; no bowl silhouette.
	flame(c, at+Vector2(0,-33)*z, zoom*(1.0 if tier == 1 else 1.18), tier >= 2)
	Art.shape(c, [Vector2(-19,-27),Vector2(-21,-40),Vector2(-13,-40),Vector2(-13,-34),Vector2(-5,-34),Vector2(-5,-39),Vector2(5,-39),Vector2(5,-34),Vector2(13,-34),Vector2(13,-40),Vector2(21,-40),Vector2(19,-27)], at,z,crown,w)
	Art.shape(c, [Vector2(-20,-28),Vector2(20,-28),Vector2(17,-23),Vector2(-17,-23)], at,z,Art.PAPER,w)
	# This small ember outlet still aligns with the existing combat muzzle.
	Art.shape(c, [Vector2(0,-33),Vector2(3,-30),Vector2(0,-27),Vector2(-3,-30)], at,z,Art.GOLD,zoom)

	if tier >= 3:
		for side in [-1,1]:
			sconce(c, at+Vector2(side*22,-19)*z, zoom, tier, crown)
	if cinder:
		# Ember seams identify the persistent-burning-ground specialization.
		for side in [-1,1]:
			c.draw_polyline(PackedVector2Array([at+Vector2(side*10,-19)*z,at+Vector2(side*12,-13)*z,at+Vector2(side*9,-8)*z,at+Vector2(side*12,-1)*z]),EMBER,1.7*zoom,true)
		flame(c, at+Vector2(-18,5)*z, zoom*0.5, false)
		flame(c, at+Vector2(18,5)*z, zoom*0.5, false)
	elif rupture:
		# Riveted iron piers and a barred firebox give the blast branch more mass.
		for side in [-1,1]:
			Art.shape(c, [Vector2(side*11,5),Vector2(side*12,-21),Vector2(side*17,-21),Vector2(side*20,5)], at,z,IRON,w)
			for y in [-16,0]:
				Art.disk(c, at+Vector2(side*15,y)*z, 1.4*zoom, Art.PAPER, 0.8*zoom)
		for x in [-2,2]:
			c.draw_line(at+Vector2(x,-9)*z,at+Vector2(x,2)*z,IRON,1.3*zoom,true)
		Art.shape(c, [Vector2(-12,-23),Vector2(12,-23),Vector2(12,-19),Vector2(-12,-19)], at,z,IRON,1.8*zoom)
	Art.shape(c, [Vector2(-20,6),Vector2(20,6),Vector2(20,12),Vector2(-20,12)], at,z,Art.PAPER,w)

static func flame(c: CanvasItem, at: Vector2, zoom: float, hot: bool) -> void:
	var z := Vector2.ONE * zoom
	Art.shape(c, [Vector2(-8,0),Vector2(-10,-9),Vector2(-6,-17),Vector2(-2,-12),Vector2(3,-25),Vector2(6,-13),Vector2(10,-17),Vector2(9,-6),Vector2(5,0)], at,z,EMBER,2.0*zoom)
	Art.shape(c, [Vector2(-4,-1),Vector2(-5,-7),Vector2(-1,-13),Vector2(1,-8),Vector2(4,-17),Vector2(5,-6),Vector2(2,-1)], at,z,Art.GOLD,0)
	if hot:
		Art.shape(c, [Vector2(-1,-1),Vector2(-2,-5),Vector2(2,-11),Vector2(3,-4),Vector2(1,-1)], at,z,Art.PAPER,0)

static func sconce(c: CanvasItem, at: Vector2, zoom: float, level: int, iron: Color) -> void:
	var z := Vector2.ONE * zoom
	Art.shape(c, [Vector2(-3,7),Vector2(-3,-6),Vector2(3,-6),Vector2(3,7)], at,z,iron,2.0*zoom)
	flame(c, at+Vector2(0,-6)*z, zoom*0.6, level >= 3)
	Art.shape(c, [Vector2(-6,-7),Vector2(6,-7),Vector2(4,-2),Vector2(-4,-2)], at,z,Art.PAPER,2.0*zoom)
