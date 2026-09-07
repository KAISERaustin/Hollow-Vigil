extends RefCounted

static func draw(a, symbol: String) -> void:
	match symbol:
		"fang": fang(a)
		"censer": censer(a)
		"seal": seal(a)

static func fang(a) -> void:
	a.link(2,-25,a.GOLD)
	a.poly([-14,-13,-4,-22,10,-18,18,-9,14,4,5,17,-16,30,-8,13,-9,2], a.PAPER,3)
	a.poly([8,-12,12,-5,8,6,0,17,-12,27,-1,8,1,-4], a.CORAL,1.5)
	a.poly([-16,-16,-3,-24,13,-18,16,-10,4,-7,-10,-9], a.IRON,2.8)
	a.poly([-15,-10,-10,-4,6,-2,14,-8,13,-13,3,-9,-7,-12], a.GOLD,2)
	a.gem(0,-15,4,5,a.CORAL)
	a.line([-4,1,0,6,-4,12], a.INK,1.6)
	a.line([-4,-2,-6,5,-4,9], a.WOOD,1.3)
	a.rivet(-9,-14)
	a.rivet(10,-11)

static func censer(a) -> void:
	a.link(0,-25,a.GOLD)
	a.line([-1,-20,-21,5],a.INK,3.5)
	a.line([1,-20,21,5],a.INK,3.5)
	a.line([0,-18,0,7],a.GOLD,2.4)
	for side in [-1,1]:
		for y in [-12,-3]: a.rivet(side*(20+y)*0.65,y)
	# Ember tongues are solid facets inside an open hanging iron bowl.
	a.poly([-14,8,-15,-2,-9,1,-4,-13,0,-3,6,-9,9,0,15,-2,13,9],a.CORAL,2)
	a.poly([-7,8,-3,-3,1,2,5,-2,8,8],a.GOLD,1.4)
	a.poly([-25,4,25,4,22,13,13,23,0,27,-14,22,-22,13],a.IRON,3)
	a.poly([-23,6,23,6,20,12,-20,12],a.GOLD,2)
	a.poly([-12,14,12,14,8,21,0,24,-8,21],a.CORAL,1.8)
	a.line([-4,14,-3,21],a.INK,2)
	a.line([4,14,3,21],a.INK,2)
	a.gem(0,28,4,5,a.GOLD)
	for x in [-16,0,16]: a.rivet(x,9)

static func seal(a) -> void:
	a.poly([-15,-27,14,-27,27,-14,28,13,14,27,-14,27,-28,13,-27,-14],a.IRON,3)
	a.poly([-12,-23,11,-23,23,-11,23,11,11,23,-11,23,-23,11,-23,-11],a.GOLD,2)
	a.poly([-9,-18,9,-18,18,-8,18,9,8,18,-9,18,-18,8,-18,-8],Color("8e6852"),2)
	# A small crucible, rather than a generic shield glyph.
	a.poly([-12,-5,12,-5,9,6,4,10,-5,10,-10,5],a.IRON,2)
	a.poly([-13,-7,13,-7,13,-2,-13,-2],a.PAPER,1.8)
	a.poly([-6,-8,-5,-15,0,-11,4,-19,7,-9],a.CORAL,1.8)
	a.poly([-8,10,8,10,12,14,-12,14],a.GOLD,1.8)
	for x in [-24,24]: a.gem(x,0,3,5,a.PAPER)
	for y in [-23,23]: a.rivet(0,y)
	a.line([-18,-19,-15,-17,-15,-12],a.INK,1.6)
	a.line([18,19,15,17,15,12],a.INK,1.6)
