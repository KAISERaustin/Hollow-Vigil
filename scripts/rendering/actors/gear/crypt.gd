extends RefCounted

static func draw(a, symbol: String) -> void:
	match symbol:
		"bell": tollstone(a)
		"chain": chain(a)
		"chime": chime(a)

static func tollstone(a) -> void:
	a.link(0,-25,a.STONE)
	a.oval(0,23,5,6,a.GOLD,2)
	a.poly([-10,-20,9,-20,16,-13,17,4,25,15,25,21,-25,21,-25,15,-18,5,-16,-12],Color("7fa6aa"),3)
	a.poly([-10,-17,8,-17,12,-11,12,5,18,12,-16,12,-12,3,-12,-10],a.STONE,1.8)
	a.poly([-26,12,25,12,27,20,-27,20],a.PAPER,2.8)
	a.poly([-16,21,17,21,12,25,-12,25],a.IRON,1.5)
	a.line([6,-17,2,-9,8,-2,5,9],a.INK,2)
	a.line([-7,-9,-7,4],a.PAPER,2)
	a.gem(0,2,3,5,a.MINT)
	a.rivet(-19,16)
	a.rivet(19,16)

static func chain(a) -> void:
	a.link(8,-24,a.STONE)
	a.link(1,-14,Color("7fa6aa"),true)
	a.link(-5,-5,a.GOLD)
	a.poly([-7,0,0,-2,4,16,12,19,21,12,18,5,29,12,25,23,12,29,2,26,-6,16,-11,25,-24,22,-29,12,-21,2,-22,13,-17,18,-11,14],Color("7fa6aa"),3)
	a.poly([-6,0,-2,0,4,18,12,23,19,19,12,26,0,23,-7,12],a.PAPER,1.5)
	a.poly([-17,2,11,-4,13,2,-15,8],a.IRON,2)
	a.rivet(-9,4)
	a.rivet(6,0)
	a.line([-24,13,-22,17,-17,20],a.INK,1.5)
	a.line([21,13,20,18,16,20],a.INK,1.5)

static func chime(a) -> void:
	a.poly([-23,-16,-18,-26,-8,-24,0,-30,8,-24,18,-26,23,-16],a.STONE,2.8)
	a.poly([-28,-17,28,-17,25,-9,-25,-9],Color("7fa6aa"),3)
	a.gem(0,-21,4,6,a.GOLD)
	for x in [-16,0,16]:
		var end: float = 28 if x == 0 else (17 if x < 0 else 22)
		a.line([x,-9,x,0],a.INK,2.5)
		a.poly([x-4,-1,x+4,-1,x+4,end,x,end+3,x-4,end],a.PAPER,2.4)
		a.poly([x-5,-2,x+5,-2,x+5,3,x-5,3],a.GOLD,1.8)
		a.line([x+1,6,x+1,end-3],Color("7fa6aa"),1.8)
		a.poly([x-4,end-3,x+4,end-3,x+4,end,x,end+3,x-4,end],a.IRON,1.6)
	a.poly([-27,-8,-22,-7,-25,2,-23,10,-29,7,-30,0],a.MINT,1.8)
	a.poly([26,-8,22,-7,27,1,25,9,31,5,30,-2],a.MINT,1.8)
	for x in [-21,21]: a.rivet(x,-13)
