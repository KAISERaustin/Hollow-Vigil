extends RefCounted

const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const Bosses = preload("res://scripts/gameplay/encounters/bosses.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
# 15% smaller than the former 0.6 sprite scale; canonical silhouettes fit 112 units.
const SIZE_SCALE := 0.51

static func shape(c: CanvasItem, points: Array, at: Vector2, z: float, color: Color, weight: float = 3.4) -> void:
	Art.shape(c, points, at, Vector2.ONE * z, color, weight * z)

static func eyes(c: CanvasItem, at: Vector2, z: float, color: Color) -> void:
	for x in [-6, 6]:
		shape(c, [Vector2(x,-3),Vector2(x+3,0),Vector2(x,3),Vector2(x-3,0)], at,z,color,0)

static func portrait(c: CanvasItem, kind: String, at: Vector2, z: float) -> void:
	match kind:
		"ruined_king":
			# A broad walking throne, chipped crown and split royal tabard.
			shape(c,[Vector2(-34,-24),Vector2(34,-24),Vector2(34,29),Vector2(22,40),Vector2(-22,40),Vector2(-34,29)],at,z,Color("74798c"))
			for side in [-1,1]:
				shape(c,[Vector2(side*23,-18),Vector2(side*40,-12),Vector2(side*37,21),Vector2(side*24,24)],at,z,Color("99948c"))
			shape(c,[Vector2(-19,-39),Vector2(-23,-54),Vector2(-9,-46),Vector2(0,-57),Vector2(8,-46),Vector2(22,-52),Vector2(18,-36)],at,z,Art.GOLD)
			shape(c,[Vector2(-18,-35),Vector2(18,-35),Vector2(15,-12),Vector2(0,-5),Vector2(-15,-12)],at,z,Color("99948c"))
			eyes(c,at+Vector2(0,-23)*z,z,Art.INK)
			shape(c,[Vector2(-15,-3),Vector2(15,-3),Vector2(19,35),Vector2(5,29),Vector2(0,43),Vector2(-18,34)],at,z,Art.LILAC)
			shape(c,[Vector2(0,5),Vector2(7,13),Vector2(0,22),Vector2(-7,13)],at,z,Art.GOLD,2)
			c.draw_polyline(PackedVector2Array([at+Vector2(8,-34)*z,at+Vector2(3,-28)*z,at+Vector2(7,-19)*z]),Art.INK,2*z,true)
		"mourning_matriarch":
			# An upright coffin carried by roots beneath a fruit-laden funeral veil.
			for side in [-1,1]:
				shape(c,[Vector2(side*12,17),Vector2(side*27,24),Vector2(side*36,43),Vector2(side*24,37),Vector2(side*9,30)],at,z,Color("727953"))
			shape(c,[Vector2(-13,-30),Vector2(13,-30),Vector2(25,-10),Vector2(18,38),Vector2(-18,38),Vector2(-25,-10)],at,z,Color("727953"))
			shape(c,[Vector2(-16,-38),Vector2(15,-38),Vector2(30,23),Vector2(19,15),Vector2(9,30),Vector2(0,21),Vector2(-12,30),Vector2(-27,20)],at,z,Color("c4b6b1"))
			shape(c,[Vector2(-12,-29),Vector2(12,-29),Vector2(8,-9),Vector2(0,-4),Vector2(-8,-9)],at,z,Art.PAPER)
			eyes(c,at+Vector2(0,-21)*z,z*0.8,Art.INK)
			for side in [-1,1]:
				c.draw_polyline(PackedVector2Array([at+Vector2(0,-36)*z,at+Vector2(side*19,-42)*z,at+Vector2(side*29,-54)*z]),Art.INK,4*z,true)
				shape(c,[Vector2(-5,-5),Vector2(5,-5),Vector2(7,1),Vector2(0,7),Vector2(-7,1)],at+Vector2(side*20,-43)*z,z,Color("a5aa73"),2)
			c.draw_line(at+Vector2(0,4)*z,at+Vector2(0,18)*z,Art.INK,2*z,true)
		"warden":
			# A hanging forest mantle, bone mask and two branch antlers. No limbs.
			shape(c,[Vector2(-16,-24),Vector2(16,-24),Vector2(22,32),Vector2(13,28),Vector2(8,39),Vector2(3,35),Vector2(0,45),Vector2(-7,36),Vector2(-11,39),Vector2(-15,28),Vector2(-22,32)],at,z,Color("567456"))
			for side in [-1,1]:
				shape(c,[Vector2(side*11,-25),Vector2(side*21,-36),Vector2(side*20,-51),Vector2(side*26,-54),Vector2(side*27,-37),Vector2(side*36,-42),Vector2(side*39,-50),Vector2(side*44,-49),Vector2(side*41,-36),Vector2(side*30,-30),Vector2(side*17,-20)],at,z,Color("a4977d"))
			shape(c,[Vector2(-16,-28),Vector2(-8,-34),Vector2(9,-34),Vector2(16,-27),Vector2(13,-10),Vector2(5,-7),Vector2(0,-2),Vector2(-5,-8),Vector2(-13,-10)],at,z,Art.PAPER)
			eyes(c,at+Vector2(0,-21)*z,z,Art.INK)
			shape(c,[Vector2(0,2),Vector2(7,11),Vector2(0,20),Vector2(-7,11)],at,z,Art.MINT,2.5)
		"cindermaw":
			# The Cinder Reliquary: a fire spirit in a broken levitating vessel.
			shape(c,[Vector2(-34,8),Vector2(34,8),Vector2(27,29),Vector2(0,45),Vector2(-27,29)],at,z,Color("454958"))
			shape(c,[Vector2(-35,6),Vector2(-23,9),Vector2(-9,7),Vector2(1,12),Vector2(18,8),Vector2(34,5),Vector2(31,16),Vector2(0,21),Vector2(-32,16)],at,z,Art.CORAL)
			for side in [-1,1]:
				shape(c,[Vector2(side*22,7),Vector2(side*24,-12),Vector2(side*30,-17),Vector2(side*30,5)],at,z,Color("454958"),2.8)
			shape(c,[Vector2(-12,9),Vector2(-20,-7),Vector2(-13,-25),Vector2(-9,-17),Vector2(-3,-36),Vector2(10,-55),Vector2(7,-34),Vector2(17,-18),Vector2(11,-5),Vector2(22,-12),Vector2(17,9)],at,z,Art.GOLD)
			shape(c,[Vector2(-5,9),Vector2(0,-9),Vector2(6,1),Vector2(4,9)],at,z,Art.PAPER,0)
			eyes(c,at+Vector2(0,-18)*z,z*0.8,Art.INK)
			shape(c,[Vector2(0,23),Vector2(5,29),Vector2(0,35),Vector2(-5,29)],at,z,Art.GOLD,2)
		"bell":
			# One crack and two open chain links keep the bell readable when small.
			shape(c,[Vector2(-13,19),Vector2(12,19),Vector2(7,32),Vector2(1,29),Vector2(-2,45),Vector2(-12,34),Vector2(-7,28)],at,z,Art.MINT)
			shape(c,[Vector2(-14,-29),Vector2(-24,-22),Vector2(-18,-16),Vector2(-28,-12),Vector2(-18,-7),Vector2(18,-7),Vector2(28,-12),Vector2(18,-16),Vector2(24,-22),Vector2(14,-29)],at,z,Art.MINT)
			shape(c,[Vector2(0,-51),Vector2(15,-39),Vector2(17,-27),Vector2(8,-21),Vector2(-10,-21),Vector2(-18,-29),Vector2(-13,-40)],at,z,Color("7fa6aa"))
			shape(c,[Vector2(0,-43),Vector2(9,-35),Vector2(8,-28),Vector2(-8,-28),Vector2(-10,-34)],at,z,Art.INK,0)
			eyes(c,at+Vector2(0,-34)*z,z*0.7,Art.MINT)
			shape(c,[Vector2(-15,-20),Vector2(14,-20),Vector2(24,17),Vector2(28,23),Vector2(-28,23),Vector2(-23,16)],at,z,Color("7fa6aa"))
			c.draw_polyline(PackedVector2Array([at+Vector2(1,-19)*z,at+Vector2(4,-7)*z,at+Vector2(-2,-1)*z,at+Vector2(2,14)*z]),Art.INK,2*z,true)
			Art.ellipse(c,at+Vector2(0,23)*z,Vector2(24,5)*z,Art.INK,0)
			for side in [-1,1]:
				c.draw_line(at+Vector2(side*23,-13)*z,at+Vector2(side*32,-6)*z,Art.INK,3*z,true)
				for y in [-2,10]:
					shape(c,[Vector2(-4,-6),Vector2(4,-6),Vector2(4,5),Vector2(-4,5)],at+Vector2(side*32,y)*z,z,Art.PAPER,2.5)
		"prior":
			# A spare broken halo, one robe fold and a small lantern echo the keeper.
			c.draw_arc(at+Vector2(-4,-26)*z,26*z,0.2,2.6,24,Art.INK,9*z,true)
			c.draw_arc(at+Vector2(-4,-26)*z,26*z,3.0,5.9,24,Art.INK,9*z,true)
			c.draw_arc(at+Vector2(-4,-26)*z,26*z,0.2,2.6,24,Art.LILAC,4*z,true)
			c.draw_arc(at+Vector2(-4,-26)*z,26*z,3.0,5.9,24,Art.LILAC,4*z,true)
			shape(c,[Vector2(1,-47),Vector2(11,-42),Vector2(14,-33),Vector2(6,-36),Vector2(2,-42)],at,z,Art.CORAL,0)
			shape(c,[Vector2(-17,-12),Vector2(8,-12),Vector2(18,35),Vector2(5,31),Vector2(-3,43),Vector2(-12,32),Vector2(-24,37)],at,z,Art.LILAC)
			shape(c,[Vector2(-4,-39),Vector2(10,-25),Vector2(7,-13),Vector2(-4,-7),Vector2(-18,-18),Vector2(-16,-28)],at,z,Art.LILAC)
			shape(c,[Vector2(-4,-31),Vector2(3,-23),Vector2(1,-17),Vector2(-8,-17),Vector2(-11,-23)],at,z,Art.INK,0)
			eyes(c,at+Vector2(-4,-23)*z,z*0.65,Art.PAPER)
			c.draw_line(at+Vector2(-4,3)*z,at+Vector2(-8,25)*z,Art.INK,2*z,true)
			c.draw_line(at+Vector2(10,-7)*z,at+Vector2(31,-11)*z,Art.INK,3*z,true)
			c.draw_line(at+Vector2(31,-11)*z,at+Vector2(31,-2)*z,Art.INK,2*z,true)
			shape(c,[Vector2(24,-2),Vector2(38,-2),Vector2(38,14),Vector2(31,20),Vector2(24,14)],at,z,Art.GOLD,2.5)
			shape(c,[Vector2(31,2),Vector2(34,9),Vector2(31,14),Vector2(28,9)],at,z,Art.PAPER,1.8)

static func draw(c: CanvasItem, e: Dictionary, at: Vector2, zoom: float) -> void:
	var z := zoom * SIZE_SCALE
	portrait(c,e.kind,at,z)
	# Typography scales separately from the smaller artwork for readable map labels.
	var font := UI.font(600,true)
	var size := maxi(7,roundi(10*zoom))
	var title: String = Bosses.DEFINITIONS[e.kind].name
	var width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var height := font.get_height(size)
	var padding := Vector2(5,2)*maxf(0.5,zoom)
	var plate := Rect2(at+Vector2(-width*0.5-padding.x,-63*z-height-padding.y*2-8*zoom),Vector2(width,height)+padding*2)
	c.draw_rect(plate,Art.PAPER)
	c.draw_rect(plate,Art.INK,false,maxf(1,1.3*zoom))
	c.draw_string(font,plate.position+padding+Vector2(0,font.get_ascent(size)),title,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Art.INK)
	var start := at+Vector2(-26,-63)*z
	c.draw_line(start,start+Vector2(52,0)*z,Art.INK,5*z)
	c.draw_line(start,start+Vector2(52*clampf(e.hp/e.max_hp,0,1),0)*z,Art.CORAL,2.5*z)
	if e.get("shield",0.0)>0:
		c.draw_line(start+Vector2(0,5)*z,start+Vector2(52*e.shield/600.0,5)*z,Art.MINT,2.5*z)
	if e.kind == "prior":
		for index in range(int(e.get("wards",0))):
			shape(c,[Vector2(0,-3),Vector2(2.5,0),Vector2(0,3),Vector2(-2.5,0)],at+Vector2(-10+index*10,51)*z,z,Art.LILAC,1.5)
