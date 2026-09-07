extends RefCounted

## Terrain companions for the architectural kit. Small landscapes, not icons.
const A = preload("res://scripts/rendering/terrain/terrain_art.gd")
const Kit = preload("res://scripts/rendering/terrain/map_landmark_art.gd")

static func tree(c: CanvasItem, at: Vector2, height: float, crown: Color, bare: bool = false) -> void:
	var z := Vector2.ONE * height / 60.0
	A.shape(c,[Vector2(-5,3),Vector2(-3,-32),Vector2(3,-32),Vector2(5,3)],at,z,Kit.WOOD,1.8)
	if bare:
		for side in [-1,1]:
			A.shape(c,[Vector2(0,-7),Vector2(side*4,-23),Vector2(side*17,-31),Vector2(side*21,-46),Vector2(side*12,-36),Vector2(side*9,-43),Vector2(side*6,-28),Vector2(0,-20)],at,z,Kit.WOOD,1.8)
		return
	for tier in range(3):
		var y := -16-tier*13
		var w := 20-tier*4
		A.shape(c,[Vector2(-w,y+7),Vector2(-w*0.5,y-9),Vector2(0,y-24),Vector2(w*0.5,y-9),Vector2(w,y+7),Vector2(5,y+4),Vector2(0,y+9),Vector2(-5,y+4)],at,z,crown.lightened(tier*0.055),1.8)
		c.draw_line(at+Vector2(0,y-14)*z,at+Vector2(6,y)*z,crown.lightened(0.24),1.2,true)

static func stone(c: CanvasItem, at: Vector2, z: float, fill: Color) -> void:
	A.shape(c,[Vector2(-16,7),Vector2(-11,-5),Vector2(1,-12),Vector2(12,-7),Vector2(18,8)],at,Vector2.ONE*z,fill,1.8)
	c.draw_polyline(PackedVector2Array([at+Vector2(-11,-5)*z,at+Vector2(0,0)*z,at+Vector2(1,-12)*z]),A.INK,1.2,true)
	c.draw_line(at,at+Vector2(7,7)*z,A.INK,1.2,true)

static func draw(c: CanvasItem, kind: String, rect: Rect2, profile: Dictionary) -> void:
	if kind=="ground_marks":
		var at := rect.get_center()
		var tint := Color(profile.roof).lightened(0.13)
		for x in [-5,1,6]:
			c.draw_line(at+Vector2(x,3),at+Vector2(x-2,-3-abs(x)*0.3),tint,1.2,true)
		c.draw_line(at+Vector2(-8,6),at+Vector2(6,6),tint,1.0,true)
		return
	var zoom := rect.size.x/120.0
	c.draw_set_transform(Vector2(rect.get_center().x,rect.end.y-20*zoom),0,Vector2.ONE*zoom)
	var top := Color(profile.roof)
	var stone_color := Color(profile.stone)
	match kind:
		"pines", "cypress", "orchard":
			A.ellipse(c,Vector2(0,0),Vector2(48,15),top.lightened(0.16),0)
			for item in [Vector3(-19,-19,49),Vector3(16,-22,58),Vector3(-33,2,44),Vector3(3,7,67),Vector3(34,5,49)]:
				tree(c,Vector2(item.x,item.y),item.z,top,kind=="orchard")
			if kind=="orchard":
				for at in [Vector2(-35,-25),Vector2(-8,-42),Vector2(24,-31),Vector2(8,-25)]:
					A.disk(c,at,4,A.CORAL,1.4)
					c.draw_line(at-Vector2(0,4),at-Vector2(0,10),A.INK,1.5,true)
		"pool":
			var points := [Vector2(-54,-9),Vector2(-44,-32),Vector2(-21,-37),Vector2(-9,-52),Vector2(20,-50),Vector2(30,-35),Vector2(51,-23),Vector2(53,-5),Vector2(30,10),Vector2(6,14),Vector2(-22,5),Vector2(-40,8)]
			Kit.poly(c,points,Color(profile.water))
			for y in [-30,-18,-6]:
				Kit.line(c,Vector2(-25+y*0.2,y),Vector2(25+y*0.4,y),1.3,A.MINT)
			stone(c,Vector2(39,-30),0.65,stone_color)
			stone(c,Vector2(-34,2),0.6,stone_color)
			reeds(c,Vector2(-40,-19))
			reeds(c,Vector2(31,4))
		"crags", "slag":
			for item in [Vector3(-26,-12,0.8),Vector3(5,-9,1.3),Vector3(34,7,0.7)]:
				var at := Vector2(item.x,item.y)
				A.shape(c,[Vector2(-28,10),Vector2(-15,-19),Vector2(-2,-43),Vector2(11,-32),Vector2(28,10)],at,Vector2.ONE*item.z,top,2)
				A.shape(c,[Vector2(-2,-43),Vector2(11,-32),Vector2(28,10),Vector2(4,1),Vector2(8,-12)],at,Vector2.ONE*item.z,stone_color.darkened(0.18),1.3)
				A.shape(c,[Vector2(-15,-19),Vector2(-2,-43),Vector2(5,-32),Vector2(1,-23),Vector2(-6,-26)],at,Vector2.ONE*item.z,stone_color,1.2)
			if kind=="slag":
				c.draw_polyline(PackedVector2Array([Vector2(-11,-20),Vector2(-18,-6),Vector2(-7,0),Vector2(-15,12)]),A.CORAL,3,true)
		"tombs":
			for item in [Vector2(-25,-22),Vector2(12,-32),Vector2(32,0),Vector2(-4,7)]:
				A.shape(c,[Vector2(-13,0),Vector2(3,-5),Vector2(17,5),Vector2(1,12)],item,Vector2.ONE,stone_color.darkened(0.15),1.5)
				A.shape(c,[Vector2(-10,1),Vector2(-10,-21),Vector2(0,-28),Vector2(8,-21),Vector2(8,1)],item,Vector2.ONE,stone_color,1.8)
				Kit.line(c,item+Vector2(-1,-19),item+Vector2(-1,-4),1.6)
				Kit.line(c,item+Vector2(-5,-14),item+Vector2(4,-14),1.6)
		"cart":
			Kit.line(c,Vector2(-40,-8),Vector2(45,7),3,Kit.WOOD)
			Kit.block(c,Rect2(-29,-28,51,25),Kit.WOOD)
			for y in [-20,-11]: Kit.line(c,Vector2(-28,y),Vector2(20,y),1.3)
			for x in [-18,15]:
				A.disk(c,Vector2(x,0),11,Kit.IRON,2)
				A.disk(c,Vector2(x,0),7,stone_color,1.2)
				for angle in range(4):
					Kit.line(c,Vector2(x,0),Vector2(x,0)+Vector2.from_angle(angle*PI/2)*7,1.5)
			for x in [-19,0]: Kit.block(c,Rect2(x,-40,16,12),A.ROAD)
		"reeds":
			for at in [Vector2(-24,-19),Vector2(5,-5),Vector2(29,-25)]: reeds(c,at)
			stone(c,Vector2(-25,5),0.8,stone_color)
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func reeds(c: CanvasItem, at: Vector2) -> void:
	for x in [-7,0,7]:
		Kit.line(c,at+Vector2(x,4),at+Vector2(x-3,-18-abs(x)),1.6)
		Kit.line(c,at+Vector2(x-3,-16-abs(x)),at+Vector2(x-3,-24-abs(x)),3,Kit.WOOD)

static func ground(c: CanvasItem, bounds: Rect2, style: String) -> void:
	var base := A.ground_color(style)
	# Broad, subdued land contours give the entire chapter a topography. Keep
	# the header quiet; strong detail is separately placed around reserved text.
	for band in range(4):
		var top := bounds.position.y+122+band*204
		for side in [-1,1]:
			var edge := 0.0 if side<0 else bounds.end.x
			var direction := float(-side)
			var reach := minf(bounds.size.x*0.34,170)
			var points := PackedVector2Array([Vector2(edge,top),Vector2(edge+direction*reach*0.65,top+23),Vector2(edge+direction*reach,top+76),Vector2(edge+direction*reach*0.7,top+132),Vector2(edge,top+173)])
			c.draw_colored_polygon(points,base.darkened(0.055 if band%2==0 else 0.085))
			var contour := PackedVector2Array([points[1]+Vector2(-direction*12,12),points[2]+Vector2(-direction*14,0),points[3]+Vector2(-direction*13,-8)])
			c.draw_polyline(contour,base.darkened(0.16),1.1,true)
