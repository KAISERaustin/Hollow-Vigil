extends RefCounted

const A = preload("res://scripts/rendering/terrain_art.gd")
const ICE := Color("96d6e6")
const LEAF := Color("93b979")
const EMBER := Color("f19b57")
const IRON := Color("626671")
const VIOLET := Color("c3a0ed")
const DARK := Color("494252")
const BLUE := Color("a9dce9")

static func poly(c: CanvasItem, points: Array, color: Color) -> void:
	A.shape(c, points, Vector2.ZERO, Vector2.ONE, color, 2.5)

static func shard(c: CanvasItem, at: Vector2, height: float, color: Color) -> void:
	A.shape(c, [Vector2(0,-height),Vector2(5,-5),Vector2(2,3),Vector2(-5,0)], at, Vector2.ONE, color, 2.0)
	c.draw_line(at + Vector2(0,-height+6), at + Vector2(0,-1), A.PAPER, 1.4, true)

static func draw(c: CanvasItem, branch: String, at: Vector2, zoom: float) -> void:
	c.draw_set_transform(at, 0, Vector2.ONE * zoom)
	match branch:
		"frostneedle":
			poly(c,[Vector2(-16,6),Vector2(-12,-24),Vector2(12,-24),Vector2(16,6)],ICE)
			poly(c,[Vector2(-22,-24),Vector2(-17,-38),Vector2(-8,-31),Vector2(0,-51),Vector2(8,-31),Vector2(17,-38),Vector2(22,-24)],ICE)
			for side in [-1,1]:
				shard(c,Vector2(side*19,0),23,ICE)
				c.draw_line(Vector2(side*8,-18),Vector2(side*5,1),A.PAPER,2,true)
			c.draw_line(Vector2(0,-17),Vector2(0,-4),A.PAPER,2,true)
			for angle in [0.0, PI/3, PI*2/3]:
				c.draw_line(Vector2(0,-10)+Vector2.from_angle(angle)*6,Vector2(0,-10)-Vector2.from_angle(angle)*6,A.PAPER,1.7,true)
		"thorn_volley":
			poly(c,[Vector2(-14,6),Vector2(-11,-22),Vector2(11,-22),Vector2(14,6)],LEAF)
			poly(c,[Vector2(-22,-18),Vector2(-27,-30),Vector2(0,-39),Vector2(27,-30),Vector2(22,-18)],A.GOLD)
			for index in range(5):
				var x := (index-2)*10.0
				var base := Vector2(x,-26-absf(x)*0.05)
				var tip := base + Vector2((index-2)*4,-19+absf(index-2)*2)
				var normal := (tip-base).normalized().orthogonal()*3
				poly(c,[base-normal,tip-normal,tip+Vector2(0,-5),tip+normal,base+normal],LEAF)
			for side in [-1,1]:
				poly(c,[Vector2(side*10,-9),Vector2(side*23,-17),Vector2(side*18,-4),Vector2(side*24,1),Vector2(side*11,5)],LEAF)
			c.draw_line(Vector2(-6,0),Vector2(6,-17),A.PAPER,2,true)
		"cinderfield":
			poly(c,[Vector2(-17,6),Vector2(-12,-10),Vector2(12,-10),Vector2(17,6)],DARK)
			poly(c,[Vector2(-26,-22),Vector2(26,-22),Vector2(19,-5),Vector2(-19,-5)],DARK)
			A.ellipse(c,Vector2(0,-23),Vector2(25,8),EMBER,2.5)
			for side in [-1,1]:
				c.draw_polyline(PackedVector2Array([Vector2(side*16,-20),Vector2(side*10,-14),Vector2(side*15,-8),Vector2(side*8,1)]),EMBER,3,true)
			poly(c,[Vector2(-12,-29),Vector2(-14,-40),Vector2(-5,-35),Vector2(0,-52),Vector2(5,-37),Vector2(14,-44),Vector2(11,-28)],EMBER)
			poly(c,[Vector2(-4,-28),Vector2(0,-40),Vector2(5,-28)],A.PAPER)
		"rupture_pyre":
			poly(c,[Vector2(-18,6),Vector2(-13,-17),Vector2(13,-17),Vector2(18,6)],IRON)
			poly(c,[Vector2(-27,-27),Vector2(27,-27),Vector2(21,-6),Vector2(-21,-6)],A.CORAL)
			for side in [-1,1]:
				poly(c,[Vector2(side*16,-28),Vector2(side*24,-30),Vector2(side*25,-6),Vector2(side*16,-6)],IRON)
				A.disk(c,Vector2(side*20,-17),2,A.PAPER,1)
			poly(c,[Vector2(-12,-31),Vector2(-8,-44),Vector2(-2,-39),Vector2(5,-53),Vector2(14,-37),Vector2(9,-29)],EMBER)
			poly(c,[Vector2(-10,-3),Vector2(10,-3),Vector2(13,4),Vector2(-13,4)],A.PAPER)
			c.draw_arc(Vector2(0,-33),23,PI+0.2,TAU-0.2,25,EMBER,2,true)
		"grave_echo":
			poly(c,[Vector2(-15,5),Vector2(-9,-11),Vector2(9,-11),Vector2(15,5)],DARK)
			poly(c,[Vector2(0,-49),Vector2(13,-30),Vector2(7,-12),Vector2(-10,-17),Vector2(-13,-32)],VIOLET)
			c.draw_polyline(PackedVector2Array([Vector2(-5,-40),Vector2(5,-31),Vector2(-4,-25),Vector2(5,-16)]),A.INK,3,true)
			for index in range(5):
				var angle := PI + index*PI/4
				var point := Vector2(cos(angle)*25,-19+sin(angle)*24)
				shard(c,point,12,VIOLET)
		"doomstone":
			poly(c,[Vector2(-20,5),Vector2(-13,-3),Vector2(13,-3),Vector2(20,5)],A.LILAC)
			poly(c,[Vector2(-12,-12),Vector2(-15,-42),Vector2(2,-54),Vector2(16,-45),Vector2(13,-14),Vector2(0,-8)],DARK)
			c.draw_line(Vector2(2,-49),Vector2(2,-15),Color("c282bb"),2,true)
			for y in [-38,-27,-16]:
				A.shape(c,[Vector2(-5,0),Vector2(0,-4),Vector2(5,0),Vector2(0,4)],Vector2(0,y),Vector2.ONE,Color("c282bb"),1.5)
			for side in [-1,1]:
				c.draw_line(Vector2(side*22,-24),Vector2(side*22,-14),A.LILAC,2,true)
				c.draw_line(Vector2(side*19,-20),Vector2(side*25,-20),A.LILAC,2,true)
		"tempest_web":
			poly(c,[Vector2(-14,6),Vector2(-9,-22),Vector2(9,-22),Vector2(14,6)],IRON)
			for side in [-1,1]:
				poly(c,[Vector2(side*5,-18),Vector2(side*23,-29),Vector2(side*25,-46),Vector2(side*18,-37),Vector2(side*14,-47),Vector2(side*12,-30)],BLUE)
				c.draw_polyline(PackedVector2Array([Vector2(side*23,-41),Vector2(side*8,-35),Vector2(side*16,-29),Vector2(0,-23)]),A.PAPER,1.6,true)
			shard(c,Vector2(0,-28),28,BLUE)
			for y in [-12,-4]:
				c.draw_line(Vector2(-10,y),Vector2(10,y),BLUE,3,true)
		"thunderseal":
			poly(c,[Vector2(-13,6),Vector2(-7,-40),Vector2(7,-40),Vector2(13,6)],DARK)
			for y in [-12,-27,-42]:
				A.ellipse(c,Vector2(0,y),Vector2(24,7),Color("b3b5f1"),2.5)
				A.ellipse(c,Vector2(0,y),Vector2(16,3),DARK,1)
			A.disk(c,Vector2(0,-51),6,BLUE,2)
			for index in range(5):
				var point := Vector2(-16+index*8,-12)
				A.disk(c,point,2,A.PAPER,1)
	poly(c,[Vector2(-19,6),Vector2(19,6),Vector2(19,12),Vector2(-19,12)],A.PAPER)
	c.draw_set_transform(Vector2.ZERO)
