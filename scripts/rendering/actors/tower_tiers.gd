extends RefCounted

# Additions share the base silhouette, palette and socket anchor at every tier.
static func details(c: CanvasItem, kind: String, at: Vector2, zoom: float, level: int) -> void:
	var a = preload("res://scripts/rendering/terrain/terrain_art.gd")
	var z := Vector2.ONE * zoom
	var w := 2.5 * zoom
	match kind:
		"rapid":
			# Reinforced collar, then a crown of needle launchers and wing plates.
			a.shape(c, [Vector2(-14,-21),Vector2(14,-21),Vector2(14,-15),Vector2(-14,-15)], at,z,a.PAPER,w)
			for side in [-1,1]:
				a.shape(c, [Vector2(side*11,-24),Vector2(side*20,-34),Vector2(side*18,-17)],at,z,a.GOLD,w)
			if level == 3:
				for side in [-1,1]:
					a.shape(c,[Vector2(side*5,-30),Vector2(side*8,-48),Vector2(side*12,-29)],at,z,a.PAPER,w)
					a.shape(c,[Vector2(side*12,-9),Vector2(side*23,-16),Vector2(side*20,4),Vector2(side*12,4)],at,z,a.GOLD,w)
				a.shape(c,[Vector2(0,-48),Vector2(5,-37),Vector2(0,-32),Vector2(-5,-37)],at,z,a.GOLD,w)
				a.disk(c,at+Vector2(0,0)*z,3*zoom,a.PAPER,zoom)
		"heavy":
			# A rune collar develops into a crystal sanctuary around the monolith.
			a.shape(c,[Vector2(-11,-9),Vector2(11,-9),Vector2(12,-3),Vector2(-12,-3)],at,z,a.PAPER,w)
			a.shape(c,[Vector2(0,-35),Vector2(3,-30),Vector2(0,-26),Vector2(-3,-30)],at,z,a.PAPER,zoom)
			if level == 3:
				for side in [-1,1]:
					a.shape(c,[Vector2(side*15,-25),Vector2(side*22,-16),Vector2(side*20,5),Vector2(side*13,5),Vector2(side*11,-16)],at,z,a.LILAC,w)
					c.draw_line(at+Vector2(side*16,-15)*z,at+Vector2(side*16,-5)*z,a.PAPER,2*zoom,true)
				a.shape(c,[Vector2(0,-54),Vector2(5,-47),Vector2(0,-41),Vector2(-5,-47)],at,z,a.LILAC,w)
				a.shape(c,[Vector2(0,-24),Vector2(4,-18),Vector2(0,-12),Vector2(-4,-18)],at,z,a.PAPER,zoom)
		"electric":
			# Conductive bands, then an outer pair of charged lightning rods.
			var blue := Color("91bbff")
			for y in [-13, -5]:
				a.shape(c,[Vector2(-10,y),Vector2(10,y),Vector2(11,y+4),Vector2(-11,y+4)],at,z,a.PAPER,w)
			for side in [-1,1]:
				a.disk(c,at+Vector2(side*14,-39)*z,3*zoom,blue,1.5*zoom)
			if level == 3:
				for side in [-1,1]:
					a.shape(c,[Vector2(side*12,5),Vector2(side*24,2),Vector2(side*23,-27),Vector2(side*19,-34),Vector2(side*18,-4)],at,z,a.LILAC,w)
					a.disk(c,at+Vector2(side*21,-32)*z,4*zoom,blue,2*zoom)
					c.draw_polyline(PackedVector2Array([at+Vector2(side*19,-36)*z,at+Vector2(side*10,-43)*z,at+Vector2(side*12,-48)*z,at+Vector2(0,-45)*z]),blue,2.5*zoom,true)
