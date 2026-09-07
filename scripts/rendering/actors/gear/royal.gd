extends RefCounted

static func draw(a, symbol: String) -> void:
	match symbol:
		"crown": crown(a)
		"signet": signet(a)
		"blade": edge(a)

static func crown(a) -> void:
	a.poly([-25,-19,-11,-8,0,-30,11,-8,24,-21,24,13,18,24,-18,24,-26,13],a.GOLD,3)
	a.poly([-23,-10,-15,-3,-10,-7,-7,11,8,11,12,-5,17,-1,23,-10,20,16,-20,16],a.PAPER,2)
	a.poly([-25,10,23,10,25,20,18,27,-18,27,-26,20],a.IRON,2.8)
	a.poly([-23,13,22,13,22,19,-23,19],a.GOLD,1.8)
	a.gem(0,15,5,8,Color("ae879b"))
	for side in [-1,1]:
		a.gem(side*16,15,2.5,4,a.PAPER)
		a.line([side*21,-12,side*18,-3,side*20,5],a.INK,1.6)
	a.poly([0,-26,4,-17,0,-11,-4,-17],a.PAPER,1.6)
	a.line([-12,21,-8,25,-4,22],a.INK,1.5)
	a.poly([18,-26,23,-30,25,-23],a.STONE,2)

static func signet(a) -> void:
	# A thick siege ring with a carved battlement face and visible inner band.
	a.oval(0,10,22,21,a.IRON,3)
	a.oval(0,11,16,15,a.GOLD,2)
	a.oval(0,12,10,10,a.IRON,2)
	a.poly([-20,-20,-10,-28,13,-27,23,-17,21,1,10,8,-13,7,-23,-3],a.GOLD,3)
	a.poly([-16,-18,-9,-23,11,-22,17,-15,15,-1,8,3,-10,2,-18,-5],a.STONE,2)
	a.poly([-12,-2,-12,-17,-7,-17,-7,-12,-2,-12,-2,-18,4,-18,4,-12,9,-12,9,-17,13,-17,13,-2],a.IRON,1.8)
	a.poly([-3,0,-3,-7,1,-11,5,-7,5,0],a.PAPER,1.4)
	a.line([-17,13,-14,21,-9,24],a.PAPER,2)
	a.line([17,9,18,15,14,22],a.INK,1.8)
	a.rivet(-19,-8)
	a.rivet(19,-10)

static func edge(a) -> void:
	a.poly([-2,-31,9,-21,8,-9,4,-6,7,-3,3,11,-5,14,-11,7,-7,-1,-4,-4,-7,-7],a.PAPER,3)
	a.poly([0,-26,4,-20,0,6,-4,10,-5,4],a.STONE,0)
	a.line([0,-24,-2,-7,0,-2,-3,7],a.INK,1.6)
	a.poly([-20,5,-12,6,-6,11,4,8,12,2,18,4,13,12,3,16,-7,18,-19,13],a.GOLD,2.8)
	a.gem(-2,12,4,5,Color("ae879b"))
	a.poly([-6,17,1,17,1,29,-5,32,-11,27],a.IRON,2.4)
	a.line([-6,21,0,23,-7,26],a.PAPER,1.4)
	a.poly([-11,27,0,29,1,33,-8,34,-13,31],a.GOLD,2)
	for x in [-14,12]: a.rivet(x,9)
