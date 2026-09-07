extends RefCounted

static func draw(a, symbol: String) -> void:
	match symbol:
		"root": rootheart(a)
		"spindle": spindle(a)
		"lens": lens(a)

static func rootheart(a) -> void:
	# The carved heart is physically caught in forked antlers and living roots.
	for side in [-1, 1]:
		a.poly([side*13,10,side*20,-5,side*17,-19,side*24,-29,side*23,-13,side*29,-18,side*25,-3,side*20,14], a.WOOD)
		a.poly([side*7,9,side*14,18,side*25,25,side*15,24,side*9,18,side*11,29,side*4,23,0,30,0,12], a.STONE)
		a.line([side*15,8,side*21,-5,side*20,-14], a.PAPER, 1.6)
	a.poly([-16,-13,-10,-21,-2,-20,1,-15,8,-22,16,-17,18,-7,13,5,0,18,-11,8,-17,-2], Color("95aa83"), 3.0)
	a.poly([-10,-12,-4,-13,0,-7,6,-14,11,-11,9,0,0,9,-8,1], Color("567464"), 2)
	a.gem(0,-1,5,10,a.MINT)
	a.line([-13,-6,-9,-2,-11,3], a.INK, 1.6)
	a.leaf(-17,9,-1,Color("95aa83"))
	a.leaf(14,15,1,Color("b7c58b"))

static func spindle(a) -> void:
	a.poly([-23,21,14,-21,21,-17,-16,27], a.WOOD, 3)
	a.poly([-19,21,14,-16,17,-15,-15,23], a.PAPER, 0)
	# Flared bone spindle ends and an off-axis winding of hooked briar.
	a.poly([8,-27,12,-32,29,-19,26,-14], a.GOLD)
	a.poly([10,-25,14,-28,25,-20,23,-18], a.PAPER, 1.2)
	a.poly([-29,14,-23,10,-9,24,-14,30], a.GOLD)
	a.poly([-26,15,-22,14,-13,24,-16,26], a.PAPER, 1.2)
	a.poly([-16,9,-19,-2,-9,1,-13,-9,-3,-5,-3,-18,4,-9,12,-7,7,1,18,4,9,9,9,20,1,12,-5,19,-7,9], Color("718960"), 2.2)
	a.line([-13,6,-5,3,2,-3,7,-9], a.INK, 2)
	a.line([-10,13,-4,9,4,6,11,6], a.PAPER, 1.5)
	a.gem(5,-13,3,4,a.MINT)

static func lens(a) -> void:
	a.poly([7,7,14,6,28,24,23,31,17,29,5,13], a.WOOD, 3)
	a.poly([14,17,18,13,24,21,20,25], a.GOLD, 2)
	a.line([19,24,23,27], a.INK, 1.5)
	a.oval(-5,-8,21,21,a.WOOD,3)
	a.oval(-5,-8,16,16,a.GOLD,2)
	a.oval(-5,-8,12,12,Color("739e91"),2)
	a.poly([-14,-8,-5,-17,4,-8,-5,1], a.MINT, 0)
	a.line([-11,-9,-6,-14,0,-13], a.PAPER, 2.2)
	a.line([-17,5,-20,-2,-18,-13], a.INK, 1.5)
	a.poly([-23,-14,-27,-23,-18,-21,-15,-27,-9,-22,-13,-17], Color("95aa83"),2)
	a.leaf(7,-19,1,Color("95aa83"))
	a.rivet(-5,9)
	a.rivet(-22,-8)
	a.rivet(12,-8)
