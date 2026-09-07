extends RefCounted

## A small architectural kit: stone courses, iron fittings, timber and carved
## crests. All motifs share the portals' native ink drawing and flat materials.
const A = preload("res://scripts/rendering/terrain/terrain_art.gd")
const Towers = preload("res://scripts/rendering/actors/expansion_tower_art.gd")
const Portal = preload("res://scripts/rendering/actors/portal_upgrade_art.gd")
const IRON := Color("48545a")
const WOOD := Color("98785d")

static func poly(c: CanvasItem, points: Array, fill: Color, width: float = 2.2) -> void:
	A.shape(c, points, Vector2.ZERO, Vector2.ONE, fill, width)

static func line(c: CanvasItem, from: Vector2, to: Vector2, width: float = 1.4, color: Color = Color.BLACK) -> void:
	c.draw_line(from, to, color, width, true)

static func block(c: CanvasItem, rect: Rect2, fill: Color, courses: bool = false) -> void:
	poly(c, [rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x,rect.end.y)], fill)
	if courses:
		for row in range(1, int(rect.size.y / 10)):
			var y := rect.position.y + row * 10
			line(c, Vector2(rect.position.x+2,y),Vector2(rect.end.x-2,y),1,fill.darkened(0.3))
			for x in range(int(rect.position.x)+7+(row%2)*8,int(rect.end.x)-2,17):
				line(c,Vector2(x,y),Vector2(x,y-8),1,fill.darkened(0.3))

static func arch(c: CanvasItem, at: Vector2, width: float, height: float, fill: Color) -> void:
	A.shape(c,[Vector2(-width,0),Vector2(-width,-height*0.7),Vector2(0,-height),Vector2(width,-height*0.7),Vector2(width,0)],at,Vector2.ONE,fill,1.8)

static func roof(c: CanvasItem, at: Vector2, width: float, height: float, fill: Color) -> void:
	A.shape(c,[Vector2(-width,0),Vector2(0,-height),Vector2(width,0)],at,Vector2.ONE,fill,2.2)
	for fraction in [0.35,0.65]:
		line(c,at+Vector2(-width*(1-fraction),-height*fraction),at+Vector2(width*(1-fraction),-height*fraction),1.2,fill.lightened(0.22))

static func battlement(c: CanvasItem, at: Vector2, width: int, stone: Color) -> void:
	block(c,Rect2(at.x-width,at.y-7,width*2,9),stone)
	for x in range(-width,width,12): block(c,Rect2(at.x+x,at.y-14,6,8),stone)

static func banner(c: CanvasItem, at: Vector2, accent: Color) -> void:
	line(c,at+Vector2(0,20),at-Vector2(0,10),2)
	A.shape(c,[Vector2(1,-9),Vector2(18,-6),Vector2(14,0),Vector2(18,5),Vector2(1,2)],at,Vector2.ONE,accent,1.6)

static func tower(c: CanvasItem, at: Vector2, stone: Color, top: Color, crenellated: bool = false) -> void:
	block(c,Rect2(at.x-13,at.y-47,26,48),stone,true)
	block(c,Rect2(at.x+7,at.y-46,6,47),stone.darkened(0.2))
	arch(c,at+Vector2(-3,-18),4,13,IRON)
	if crenellated: battlement(c,at+Vector2(0,-45),17,stone)
	else: roof(c,at+Vector2(0,-46),20,23,top)
	block(c,Rect2(at.x-16,at.y-3,32,7),stone)

static func foundation(c: CanvasItem, stone: Color) -> void:
	poly(c,[Vector2(-48,8),Vector2(-34,-1),Vector2(35,-1),Vector2(48,8),Vector2(35,17),Vector2(-37,17)],stone.darkened(0.2))
	line(c,Vector2(-33,12),Vector2(32,12),1.2)

static func draw(c: CanvasItem, kind: String, rect: Rect2, profile: Dictionary) -> void:
	var zoom := rect.size.x / 120.0
	c.draw_set_transform(Vector2(rect.get_center().x,rect.end.y-20*zoom),0,Vector2.ONE*zoom)
	var stone := Color(profile.stone)
	var top := Color(profile.roof)
	match kind:
		"watchtower":
			foundation(c,stone)
			for x in [-34,34]:
				block(c,Rect2(x-4,-27,8,34),WOOD)
				roof(c,Vector2(x,-27),5,8,stone)
			block(c,Rect2(-35,-13,70,7),WOOD)
			tower(c,Vector2(0,4),stone,top)
			arch(c,Vector2(0,3),6,17,WOOD)
			banner(c,Vector2(0,-63),A.GOLD)
			Portal.ornament(c,"leaf",Vector2(0,-31),0.55,A.MINT)
		"watermill":
			foundation(c,stone)
			block(c,Rect2(-39,-39,56,44),stone,true)
			roof(c,Vector2(-11,-38),36,26,top)
			for x in [-30,-11,8]: block(c,Rect2(x-2,-36,4,37),WOOD)
			line(c,Vector2(-36,-34),Vector2(12,-5),3,WOOD)
			arch(c,Vector2(-11,5),7,22,IRON)
			A.disk(c,Vector2(29,-9),23,WOOD,2.5)
			A.disk(c,Vector2(29,-9),16,IRON,2)
			for spoke in range(10):
				var ray := Vector2.from_angle(spoke*TAU/10.0)
				line(c,Vector2(29,-9)+ray*5,Vector2(29,-9)+ray*22,3,A.ROAD)
			A.disk(c,Vector2(29,-9),5,A.GOLD,1.6)
		"foundry":
			foundation(c,stone)
			for x in [-29,23]:
				block(c,Rect2(x-7,-69,14,62),IRON,true)
				block(c,Rect2(x-10,-71,20,7),stone)
			block(c,Rect2(-35,-33,70,38),stone,true)
			battlement(c,Vector2(0,-32),40,IRON)
			for x in [-18,18]:
				arch(c,Vector2(x,3),12,28,IRON)
				A.shape(c,[Vector2(-6,0),Vector2(-8,-8),Vector2(0,-20),Vector2(2,-10),Vector2(7,-13),Vector2(6,0)],Vector2(x,1),Vector2.ONE,A.CORAL,1.4)
				line(c,Vector2(x-8,-3),Vector2(x+8,-3),2)
			Portal.ornament(c,"anvil",Vector2(0,-39),0.75,A.GOLD)
		"belfry":
			foundation(c,stone)
			block(c,Rect2(-31,-29,62,33),stone,true)
			roof(c,Vector2(0,-28),40,20,top)
			block(c,Rect2(-13,-59,26,65),stone,true)
			arch(c,Vector2(0,-29),9,24,IRON)
			Portal.ornament(c,"bell",Vector2(0,-40),0.6,A.GOLD)
			roof(c,Vector2(0,-59),21,22,top)
			for x in [-26,26]: arch(c,Vector2(x,-1),4,18,IRON)
			for x in [-18,12]: block(c,Rect2(x,0,6,11),stone)
		"observatory":
			foundation(c,stone)
			for x in [-31,31]: tower(c,Vector2(x,6),stone,top)
			block(c,Rect2(-20,-28,40,35),stone,true)
			arch(c,Vector2(0,6),9,23,IRON)
			block(c,Rect2(-13,-45,26,10),IRON)
			A.disk(c,Vector2(0,-58),21,top,2.2)
			Towers.crescent(c,Vector2(0,-58),18,A.PAPER)
			A.disk(c,Vector2(-2,-58),4,A.MINT,1.5)
			for x in [-15,15]: line(c,Vector2(x,-36),Vector2(x*0.5,-48),3)
		"fortress":
			foundation(c,stone)
			block(c,Rect2(-34,-39,68,45),stone,true)
			battlement(c,Vector2(0,-38),36,IRON)
			for x in [-33,33]: tower(c,Vector2(x,7),stone,top,true)
			arch(c,Vector2(0,6),12,29,IRON)
			for x in [-6,0,6]: line(c,Vector2(x,-14),Vector2(x,4),1.8,A.ROAD)
			banner(c,Vector2(-32,-59),A.CORAL)
			Portal.ornament(c,"shield",Vector2(0,-34),0.65,A.GOLD)
		"ruins":
			foundation(c,stone)
			poly(c,[Vector2(-38,5),Vector2(-38,-50),Vector2(-30,-55),Vector2(-25,-44),Vector2(-17,-48),Vector2(-14,-12),Vector2(6,-20),Vector2(16,-8),Vector2(31,-33),Vector2(39,-29),Vector2(39,6)],stone)
			arch(c,Vector2(-27,-12),4,19,IRON)
			for y in [-33,-19,-5]: line(c,Vector2(-36,y),Vector2(-19,y),1.2,stone.darkened(0.32))
			line(c,Vector2(-4,-9),Vector2(5,-2),2)
			for x in [-33,-7,19]: block(c,Rect2(x,5,14,8),stone)
		"orchard_shrine":
			foundation(c,stone)
			for side in [-1,1]:
				poly(c,[Vector2(side*29,8),Vector2(side*24,-18),Vector2(side*36,-36),Vector2(side*32,-58),Vector2(side*23,-42),Vector2(side*11,-53),Vector2(side*19,-32),Vector2(side*12,-12),Vector2(side*20,8)],WOOD)
				line(c,Vector2(side*28,-22),Vector2(side*44,-36),3)
				Portal.ornament(c,"veil",Vector2(side*40,-22),0.65,A.PAPER)
			block(c,Rect2(-16,-26,32,32),stone,true)
			roof(c,Vector2(0,-26),24,20,top)
			Portal.ornament(c,"coffin",Vector2(0,-9),0.9,WOOD)
			Portal.ornament(c,"leaf",Vector2(0,-53),0.9,A.GOLD)
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
