extends RefCounted

## Shared native silhouettes for Ironspike, Moonwheel, Hex Lantern and Caltrop Keep.
## All stages compose shared geometry; drawing never creates gameplay state.
const A = preload("res://scripts/rendering/terrain/terrain_art.gd")
const IRON := Color("69777e")
const WOOD := Color("9b7960")
const BONE := Color("ede4c9")
const ROSE := Color("c28cab")

static func poly(c: CanvasItem, points: Array, color: Color) -> void:
	A.shape(c, points, Vector2.ZERO, Vector2.ONE, color, 2.5)

static func line(c: CanvasItem, a: Vector2, b: Vector2, width: float = 2.0) -> void:
	c.draw_line(a, b, A.INK, width, true)

static func base(c: CanvasItem, color: Color, wide: float = 16.0) -> void:
	poly(c, [Vector2(-wide, 6), Vector2(-wide + 3, -13), Vector2(wide - 3, -13), Vector2(wide, 6)], color)
	poly(c, [Vector2(-wide - 3, 6), Vector2(wide + 3, 6), Vector2(wide + 3, 11), Vector2(-wide - 3, 11)], A.PAPER)

static func diamond(c: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	A.shape(c, [Vector2(0, -radius), Vector2(radius * 0.6, 0), Vector2(0, radius), Vector2(-radius * 0.6, 0)], at, Vector2.ONE, color, 2)

static func spike(c: CanvasItem, at: Vector2, radius: float = 6) -> void:
	A.shape(c, [Vector2(-radius, radius * 0.6), Vector2(-2, -1), Vector2(0, -radius), Vector2(2, -1), Vector2(radius, radius * 0.6), Vector2(0, 2)], at, Vector2.ONE, IRON, 1.5)

static func crescent(c: CanvasItem, at: Vector2, radius: float, accent: Color) -> void:
	var points: Array = []
	for i in range(17):
		var angle := -PI * 0.72 + float(i) / 16.0 * PI * 1.44
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	for i in range(16, -1, -1):
		var angle := -PI * 0.72 + float(i) / 16.0 * PI * 1.44
		points.append(Vector2(-radius * 0.3, 0) + Vector2(cos(angle), sin(angle)) * radius * 0.82)
	A.shape(c, points, at, Vector2.ONE, accent, 2.2)

static func draw(c: CanvasItem, kind: String, at: Vector2, zoom: float, level: int = 1, branch: String = "", aim_angle: float = -PI / 2.0) -> void:
	c.draw_set_transform(at, 0, Vector2.ONE * zoom)
	match kind:
		"ironspike":
			ironspike_base(c, level, branch)
			# Rotate only the mounted bow; the pedestal stays on its socket.
			var pivot: Vector2 = Balance.PROJECTILES.ironspike.muzzle
			var rotation := aim_angle + PI / 2.0
			c.draw_set_transform(at + (pivot - pivot.rotated(rotation)) * zoom, rotation, Vector2.ONE * zoom)
			ironspike_bow(c, level, branch)
		"moonwheel": moonwheel(c, level, branch)
		"hex_lantern": hex_lantern(c, level, branch)
		"caltrop_keep": caltrop_keep(c, level, branch)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func ironspike_base(c: CanvasItem, level: int, branch: String) -> void:
	base(c, WOOD)
	var siege := branch == "siegebreaker"
	var battery := branch == "needle_battery"
	if level >= 2:
		for side in [-1, 1]:
			poly(c, [Vector2(side * 12, 5), Vector2(side * 24, 5), Vector2(side * 17, -18), Vector2(side * 11, -18)], IRON)
	poly(c, [Vector2(-7, -6), Vector2(-7, -32), Vector2(7, -32), Vector2(7, -6)], WOOD)
	if level >= 2:
		poly(c, [Vector2(-11, -8), Vector2(11, -8), Vector2(11, -2), Vector2(-11, -2)], IRON)
		A.disk(c, Vector2(0, -5), 2.5, A.GOLD, 1)
	if siege:
		poly(c, [Vector2(-13, 3), Vector2(-13, -15), Vector2(0, -20), Vector2(13, -15), Vector2(13, 3)], BONE)
		line(c, Vector2(0, -14), Vector2(0, 0), 3)
	if battery:
		poly(c, [Vector2(-17, 4), Vector2(-17, -6), Vector2(17, -6), Vector2(17, 4)], A.GOLD)
		for x in [-10, 0, 10]: line(c, Vector2(x, -4), Vector2(x, 2))

static func ironspike_bow(c: CanvasItem, level: int, branch: String) -> void:
	var siege := branch == "siegebreaker"
	var battery := branch == "needle_battery"
	# The horizontal bow makes this legible beside Ashneedle's pointed roof.
	poly(c, [Vector2(-28, -30), Vector2(-22, -21), Vector2(-11, -25), Vector2(0, -29), Vector2(11, -25), Vector2(22, -21), Vector2(28, -30), Vector2(18, -26), Vector2(0, -35), Vector2(-18, -26)], BONE)
	line(c, Vector2(-23, -22), Vector2(0, -10))
	line(c, Vector2(0, -10), Vector2(23, -22))
	var barrels := [-12, 0, 12] if battery else [0]
	for x in barrels:
		line(c, Vector2(x, -8), Vector2(x, -42), 3 if not siege else 5)
		diamond(c, Vector2(x, -44), 8 if siege else 5, BONE)
	if level >= 3:
		for side in [-1, 1]:
			poly(c, [Vector2(side * 16, -17), Vector2(side * 25, -36), Vector2(side * 26, -20)], IRON)

static func moonwheel(c: CanvasItem, level: int, branch: String) -> void:
	base(c, IRON, 13)
	poly(c, [Vector2(-8, 1), Vector2(-7, -23), Vector2(7, -23), Vector2(8, 1)], A.MINT)
	poly(c, [Vector2(-13, -16), Vector2(-18, -28), Vector2(-16, -36), Vector2(-9, -23), Vector2(9, -23), Vector2(16, -36), Vector2(18, -28), Vector2(13, -16)], IRON)
	var orbit := branch == "orbit_crown"
	var reaper := branch == "reaper_wheel"
	if orbit:
		A.ellipse(c, Vector2(0, -28), Vector2(29, 12), A.ROAD, 2.5)
		for point in [Vector2(-23, -30), Vector2(1, -42), Vector2(22, -25)]:
			crescent(c, point, 10, A.MINT)
		A.disk(c, Vector2(0, -26), 7, BONE, 2)
	else:
		crescent(c, Vector2(0, -32), 23 if reaper else 17, BONE)
		A.disk(c, Vector2(0, -32), 4, A.MINT, 1.5)
		if reaper:
			for y in [-47, -33, -19]:
				poly(c, [Vector2(16, y - 5), Vector2(29, y - 1), Vector2(18, y + 4)], A.MINT)
	if level >= 2:
		poly(c, [Vector2(-10, -10), Vector2(10, -10), Vector2(11, -5), Vector2(-11, -5)], BONE)
	if level >= 3:
		for side in [-1, 1]:
			poly(c, [Vector2(side * 12, 4), Vector2(side * 22, -10), Vector2(side * 18, -20), Vector2(side * 12, -12)], A.MINT)
		diamond(c, Vector2(0, 0), 4, BONE)

static func hex_lantern(c: CanvasItem, level: int, branch: String) -> void:
	base(c, A.LILAC, 13)
	var oath := branch == "oathbrand"
	var witch := branch == "witchlight"
	poly(c, [Vector2(-9, 4), Vector2(-7, -12), Vector2(7, -12), Vector2(9, 4)], IRON)
	poly(c, [Vector2(-11, -10), Vector2(-14, -33), Vector2(14, -33), Vector2(11, -10)], ROSE if not witch else A.LILAC)
	poly(c, [Vector2(-18, -33), Vector2(0, -44), Vector2(18, -33)], IRON)
	line(c, Vector2(-9, -32), Vector2(-7, -11))
	line(c, Vector2(9, -32), Vector2(7, -11))
	# Eye-shaped aperture is the defining identity, never a fire bowl.
	poly(c, [Vector2(-8, -23), Vector2(0, -29), Vector2(8, -23), Vector2(0, -17)], BONE)
	line(c, Vector2(0, -26), Vector2(0, -20), 2.5)
	A.disk(c, Vector2(0, -47), 3, BONE, 1.5)
	if level >= 2:
		poly(c, [Vector2(-14, -11), Vector2(14, -11), Vector2(15, -6), Vector2(-15, -6)], BONE)
		for side in [-1, 1]:
			poly(c, [Vector2(side * 11, -37), Vector2(side * 17, -48), Vector2(side * 20, -35)], A.LILAC)
	if level >= 3:
		for side in [-1, 1]:
			line(c, Vector2(side * 17, -32), Vector2(side * 23, -28), 2.5)
			line(c, Vector2(side * 23, -28), Vector2(side * 23, -12))
			diamond(c, Vector2(side * 23, -9), 5, ROSE)
	if oath:
		poly(c, [Vector2(-4, -44), Vector2(0, -58), Vector2(4, -44)], ROSE)
		for y in [-36, -7, 1]: diamond(c, Vector2(0, y), 3, ROSE)
	if witch:
		for side in [-1, 1]:
			poly(c, [Vector2(side * 19, -22), Vector2(side * 28, -22), Vector2(side * 27, -12), Vector2(side * 20, -12)], A.LILAC)
			A.disk(c, Vector2(side * 23.5, -17), 2, BONE, 1)
			poly(c, [Vector2(side * 17, -23), Vector2(side * 23, -29), Vector2(side * 30, -23)], IRON)

static func caltrop_keep(c: CanvasItem, level: int, branch: String) -> void:
	base(c, A.CORAL, 19)
	poly(c, [Vector2(-17, 4), Vector2(-17, -23), Vector2(17, -23), Vector2(17, 4)], A.CORAL)
	poly(c, [Vector2(-21, -22), Vector2(-21, -31), Vector2(-13, -31), Vector2(-13, -26), Vector2(-5, -26), Vector2(-5, -33), Vector2(5, -33), Vector2(5, -26), Vector2(13, -26), Vector2(13, -31), Vector2(21, -31), Vector2(21, -22)], IRON)
	poly(c, [Vector2(-10, -15), Vector2(10, -15), Vector2(10, -3), Vector2(-10, -3)], A.BACKDROP)
	spike(c, Vector2(0, -8), 5)
	if level >= 2:
		for side in [-1, 1]:
			poly(c, [Vector2(side * 12, -20), Vector2(side * 18, -20), Vector2(side * 18, 3), Vector2(side * 12, 3)], BONE)
	if level >= 3:
		for side in [-1, 1]:
			poly(c, [Vector2(side * 17, -8), Vector2(side * 25, -16), Vector2(side * 25, 4), Vector2(side * 17, 4)], IRON)
		spike(c, Vector2(0, -36), 8)
	if branch == "dreadjaw":
		poly(c, [Vector2(-14, -1), Vector2(-14, -19), Vector2(-8, -13), Vector2(-4, -20), Vector2(0, -13), Vector2(5, -20), Vector2(9, -13), Vector2(14, -19), Vector2(14, -1)], BONE)
		poly(c, [Vector2(-14, 1), Vector2(-9, -6), Vector2(-4, 1), Vector2(1, -6), Vector2(6, 1), Vector2(11, -6), Vector2(15, 1)], IRON)
	elif branch == "scatterworks":
		for x in [-14, 0, 14]:
			poly(c, [Vector2(x - 5, -21), Vector2(x - 6, -35), Vector2(x + 6, -35), Vector2(x + 5, -21)], A.GOLD)
			poly(c, [Vector2(x - 4, -34), Vector2(x + 4, -34), Vector2(x + 4, -29), Vector2(x - 4, -29)], A.BACKDROP)
