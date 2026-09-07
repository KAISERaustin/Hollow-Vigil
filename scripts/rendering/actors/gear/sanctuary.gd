extends RefCounted

static func draw(a, symbol: String) -> void:
	match symbol:
		"eclipse": shard(a)
		"rosary": rosary(a)
		"mirror": mirror(a)

static func shard(a) -> void:
	# A fractured lunar mineral: crescent contour, separated shards, gold binding.
	a.poly([10,-28,-7,-27,-21,-16,-25,0,-18,15,-5,23,11,20,19,10,7,14,-6,7,-9,-4,-5,-17],a.LILAC,3)
	a.poly([-8,-21,-17,-11,-19,1,-11,13,-3,16,-10,4,-11,-8],Color("786589"),1.5)
	a.poly([-20,-10,-10,-17,-7,-23,-15,-21],a.PAPER,1.5)
	a.poly([8,-10,17,-17,25,-10,20,0,13,3],Color("ae879b"),2.6)
	a.poly([15,-12,20,-10,16,-3,12,-3],a.PAPER,0)
	a.poly([18,12,28,7,27,15,22,20],a.GOLD,2)
	a.poly([-17,13,-11,11,3,21,-1,28,-7,30,-12,22,-20,19],a.GOLD,2.2)
	a.gem(-8,22,3,5,Color("ae879b"))
	a.line([-22,0,-16,-2,-14,5],a.INK,1.6)
	a.line([-5,-18,-10,-12,-8,-6],a.INK,1.6)

static func rosary(a) -> void:
	var beads := [Vector2(-1,-25),Vector2(-13,-21),Vector2(-23,-12),Vector2(-26,1),Vector2(-20,13),Vector2(-9,19),Vector2(7,19),Vector2(20,12),Vector2(26,-1),Vector2(21,-14),Vector2(11,-23)]
	var string_points := []
	for bead in beads:
		string_points.append(bead.x)
		string_points.append(bead.y)
	string_points.append(beads[0].x)
	string_points.append(beads[0].y)
	a.line(string_points,a.INK,3)
	for index in range(beads.size()):
		var p: Vector2 = beads[index]
		a.oval(p.x,p.y,4.8,5.4,Color("ae879b") if index % 3 != 0 else a.PAPER,2)
		a.line([p.x-1,p.y-2,p.x+1,p.y-3],a.GOLD,1.4)
	a.poly([-5,18,4,18,5,23,10,24,8,30,-8,30,-10,24,-5,23],a.GOLD,2)
	a.gem(0,25,4,7,Color("884658"))
	a.poly([-7,-24,-3,-30,4,-29,7,-24,2,-21],a.GOLD,1.8)
	a.poly([-2,21,-6,23,-7,28,-3,32,2,31,5,27,0,29,-3,27,-3,24],a.GOLD,1.5)

static func mirror(a) -> void:
	a.poly([-5,15,6,15,8,29,3,33,-4,30,-8,24],a.IRON,2.6)
	a.poly([-10,16,10,16,8,22,-8,22],a.GOLD,2)
	a.poly([0,-32,17,-23,22,-6,17,12,0,22,-17,12,-22,-6,-17,-23],a.GOLD,3)
	a.poly([0,-26,12,-20,16,-6,12,8,0,15,-12,8,-16,-6,-12,-20],a.LILAC,2.4)
	a.poly([-11,-16,-2,-22,-7,-8,-12,-3],a.PAPER,0)
	a.poly([9,-17,12,-5,9,6,2,10,4,-1],Color("786589"),0)
	a.line([1,-24,-4,-11,4,-5,-3,4,0,13],a.INK,2.5)
	a.line([-4,-11,-12,-7],a.INK,1.5)
	a.line([4,-5,12,-1],a.INK,1.5)
	a.gem(0,-29,3,4,Color("ae879b"))
	for side in [-1,1]:
		a.gem(side*18,-7,2,4,a.PAPER)
		a.poly([side*11,12,side*15,12,side*23,23,side*17,21,side*14,28],Color("ae879b"),2)
