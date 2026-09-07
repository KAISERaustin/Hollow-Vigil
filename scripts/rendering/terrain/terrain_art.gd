class_name VigilTerrainArt
extends RefCounted

# Shared flat palette. All artwork uses filled shapes with black outlines.
const INK := Color.BLACK
const PAPER := Color("e8ddbd")
const ROAD := Color("dfd0ab")
const BACKDROP := Color("222a30")
const GOLD := Color("e0b568")
const CORAL := Color("db8d73")
const LILAC := Color("b49dcc")
const MINT := Color("93c9bc")
const BIOME_COLORS := {
	"castle_ruin": Color("777985"),
	"mourning_orchard": Color("a5aa73"),
	"forest": Color("95aa83"),
	"ashen_forge": Color("bb8c76"),
	"drowned_crypt": Color("7fa6aa"),
	"bloodmoon_sanctuary": Color("ae879b")
}

static func ground_color(style: String) -> Color:
	return BIOME_COLORS.get(style, BIOME_COLORS.forest)

static func polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, width: float = 2.0) -> void:
	canvas.draw_colored_polygon(points, fill)
	if width <= 0.0:
		return
	var edge := points.duplicate()
	edge.append(points[0])
	canvas.draw_polyline(edge, INK, width, true)

static func shape(canvas: CanvasItem, points: Array, at: Vector2, scale: Vector2, fill: Color, width: float = 2.0) -> void:
	var vertices := PackedVector2Array()
	for p in points:
		vertices.append(at + p * scale)
	polygon(canvas, vertices, fill, width)

static func disk(canvas: CanvasItem, at: Vector2, radius: float, fill: Color, width: float = 2.0) -> void:
	canvas.draw_circle(at, radius, fill)
	canvas.draw_arc(at, radius, 0, TAU, 40, INK, width, true)

static func ellipse(canvas: CanvasItem, at: Vector2, radius: Vector2, fill: Color, width: float = 2.0) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		points.append(at + Vector2.from_angle(TAU * i / 40.0) * radius)
	polygon(canvas, points, fill, width)

static func socket(canvas: CanvasItem, at: Vector2) -> void:
	# Shared worn stone surface; all details scale with the cached terrain.
	disk(canvas, at + Vector2(0, 3), 20.0, Color("a4977d"))
	disk(canvas, at, 19.0, PAPER)
	canvas.draw_arc(at, 16.5, 3.45, 5.65, 18, Color("f5ecd3"), 1.6, true)
	# Fixed local grain stays still across redraws, camera movement and saves.
	for index in range(22):
		var angle := float(index) * 2.399963
		var radius := sqrt((float(index) + 0.5) / 22.0) * 15.0
		var grain := at + Vector2.from_angle(angle) * radius
		var tint := Color("c8ba98") if index % 3 == 0 else Color("d7c9a8")
		canvas.draw_circle(grain, 0.45 + float(index % 3) * 0.15, tint, true, -1.0, true)
	canvas.draw_line(at + Vector2(-10, -4), at + Vector2(-6, -5), Color("c8ba98"), 0.8, true)
	canvas.draw_line(at + Vector2(4, 8), at + Vector2(8, 7), Color("c8ba98"), 0.8, true)
	canvas.draw_arc(at, 14.5, 0.15, PI - 0.15, 18, Color("a4977d"), 1.2, true)
	for angle in [0.65, 2.5, 4.2]:
		canvas.draw_line(at + Vector2.from_angle(angle) * 15, at + Vector2.from_angle(angle) * 19, INK, 1.2, true)

static func portal(canvas: CanvasItem, at: Vector2, zoom: float, core: bool) -> void:
	if core:
		# Cut stone, a solid ink recess and a mint heart share the rifts' language.
		# Keep the silhouette inside the existing core culling margin.
		var z := Vector2.ONE * zoom
		var w := 2.5 * zoom
		ellipse(canvas, at + Vector2(0, 17) * z, Vector2(28, 7) * z, INK, 0)
		shape(canvas, [Vector2(-24, 10), Vector2(-22, -18), Vector2(-12, -32), Vector2(12, -32), Vector2(22, -18), Vector2(24, 10)], at, z, PAPER, w)
		shape(canvas, [Vector2(-14, 9), Vector2(-13, -15), Vector2(-7, -23), Vector2(7, -23), Vector2(13, -15), Vector2(14, 9)], at, z, INK, w)
		for side in [-1, 1]:
			shape(canvas, [Vector2(side * 16, 9), Vector2(side * 18, -10), Vector2(side * 26, -4), Vector2(side * 27, 10)], at, z, MINT, w)
			canvas.draw_line(at + Vector2(side * 17, -24) * z, at + Vector2(side * 12, -19) * z, INK, 1.5 * zoom, true)
		# The intact heart and gold crest distinguish home from a hostile rift.
		shape(canvas, [Vector2(0, -20), Vector2(9, -7), Vector2(0, 7), Vector2(-9, -7)], at, z, MINT, 1.8 * zoom)
		shape(canvas, [Vector2(0, -17), Vector2(0, 3), Vector2(-6, -7)], at, z, PAPER, 0)
		shape(canvas, [Vector2(-7, -30), Vector2(0, -40), Vector2(7, -30), Vector2(0, -26)], at, z, GOLD, w)
		shape(canvas, [Vector2(-27, 10), Vector2(27, 10), Vector2(24, 17), Vector2(-24, 17)], at, z, PAPER, w)
		return
	var accent := MINT if core else LILAC
	var center := at + Vector2(0, -5) * zoom
	ellipse(canvas, center, Vector2(23, 29) * zoom, accent, 2.5 * zoom)
	ellipse(canvas, center, Vector2(14, 20) * zoom, INK, 2.0 * zoom)
	canvas.draw_line(center + Vector2(-17, -9) * zoom, center + Vector2(-17, 4) * zoom, PAPER, 2.5 * zoom, true)

static func sentinel(canvas: CanvasItem, kind: String, at: Vector2, zoom: float, level: int = 1, branch: String = "") -> void:
	if level == 4 and Balance.valid_branch(kind, branch):
		preload("res://scripts/rendering/actors/tower_branches.gd").draw(canvas, branch, at, zoom)
		return
	var z := Vector2.ONE * zoom
	var w := 2.5 * zoom
	match kind:
		"rapid":
			shape(canvas, [Vector2(-13, 7), Vector2(-11, -24), Vector2(11, -24), Vector2(13, 7)], at, z, GOLD, w)
			shape(canvas, [Vector2(-17, -23), Vector2(0, -42), Vector2(17, -23)], at, z, GOLD, w)
			canvas.draw_line(at + Vector2(0, -16) * z, at + Vector2(0, -6) * z, INK, 3.5 * zoom)
		"splash":
			shape(canvas, [Vector2(-10, 7), Vector2(-7, -10), Vector2(7, -10), Vector2(10, 7)], at, z, CORAL, w)
			shape(canvas, [Vector2(-18, -18), Vector2(18, -18), Vector2(12, -5), Vector2(-12, -5)], at, z, CORAL, w)
			shape(canvas, [Vector2(-9, -22), Vector2(-7, -30), Vector2(-1, -25), Vector2(4, -40), Vector2(10, -25), Vector2(7, -18), Vector2(-5, -18)], at, z, GOLD, w)
		"electric":
			var blue := Color("91bbff")
			shape(canvas, [Vector2(-12, 7), Vector2(-8, -21), Vector2(8, -21), Vector2(12, 7)], at, z, LILAC, w)
			for side in [-1, 1]:
				shape(canvas, [Vector2(side * 7, -15), Vector2(side * 18, -25), Vector2(side * 14, -40), Vector2(side * 10, -28), Vector2(side * 4, -23)], at, z, blue, w)
			disk(canvas, at + Vector2(0, -29) * z, 7 * zoom, blue, w)
		_:
			shape(canvas, [Vector2(-13, 7), Vector2(-10, -29), Vector2(0, -43), Vector2(10, -29), Vector2(13, 7)], at, z, LILAC, w)
			shape(canvas, [Vector2(0, -25), Vector2(5, -18), Vector2(0, -11), Vector2(-5, -18)], at, z, INK, zoom)
	shape(canvas, [Vector2(-17, 6), Vector2(17, 6), Vector2(17, 12), Vector2(-17, 12)], at, z, PAPER, w)
	if level >= 2:
		preload("res://scripts/rendering/actors/tower_tiers.gd").details(canvas, kind, at, zoom, clampi(level, 1, 3))

static func scenery(canvas: CanvasItem, style: String, at: Vector2, extent: float) -> void:
	if style == "mourning_orchard":
		preload("res://scripts/rendering/actors/orchard_art.gd").scenery(canvas, at, extent)
		return
	var z := Vector2.ONE * extent / 30.0
	match style:
		"castle_ruin":
			# A broken ashlar pier: the same small footprint as trees and crystals.
			var stone := Color("b4adbd")
			var face := Color("8f889c")
			shape(canvas, [Vector2(-14, 8), Vector2(9, 6), Vector2(15, 11), Vector2(10, 15), Vector2(-13, 14)], at, z, face)
			shape(canvas, [Vector2(-9, 9), Vector2(-9, -13), Vector2(-4, -17), Vector2(0, -12), Vector2(5, -16), Vector2(10, -12), Vector2(9, 9)], at, z, stone)
			shape(canvas, [Vector2(4, -12), Vector2(10, -12), Vector2(9, 9), Vector2(4, 11)], at, z, face, 1.0)
			canvas.draw_line(at + Vector2(-9, -4) * z, at + Vector2(4, -4) * z, INK, 1.2, true)
			canvas.draw_line(at + Vector2(-8, 3) * z, at + Vector2(4, 3) * z, INK, 1.2, true)
			canvas.draw_line(at + Vector2(-3, -4) * z, at + Vector2(-3, 3) * z, INK, 1.2, true)
			canvas.draw_polyline(PackedVector2Array([at + Vector2(0, -12) * z, at + Vector2(-2, -8) * z, at + Vector2(1, -6) * z]), INK, 1.2, true)
			shape(canvas, [Vector2(-17, 10), Vector2(-16, 5), Vector2(-11, 4), Vector2(-7, 8), Vector2(-9, 12)], at, z, stone, 1.3)
		"forest":
			shape(canvas, [Vector2(-2, 4), Vector2(3, 4), Vector2(3, 13), Vector2(-2, 13)], at, z, Color("a4977d"), 1.5)
			shape(canvas, [Vector2(0, -16), Vector2(8, -3), Vector2(5, -3), Vector2(13, 8), Vector2(-12, 8), Vector2(-5, -3), Vector2(-8, -3)], at, z, Color("567456"))
			shape(canvas, [Vector2(0, -12), Vector2(0, 5), Vector2(-8, 5), Vector2(-2, -3), Vector2(-5, -3)], at, z, Color("799269"), 0.0)
			canvas.draw_line(at + Vector2(-4, 1) * z, at + Vector2(4, 1) * z, INK, 1.2, true)
		"ashen_forge":
			shape(canvas, [Vector2(-13, 8), Vector2(-9, -5), Vector2(1, -10), Vector2(12, -2), Vector2(14, 8)], at, z, Color("80685d"))
			shape(canvas, [Vector2(-9, -4), Vector2(1, -9), Vector2(11, -2), Vector2(2, 1)], at, z, Color("a18b75"), 1.0)
			canvas.draw_polyline(PackedVector2Array([at + Vector2(1, -7) * z, at + Vector2(-2, 0) * z, at + Vector2(3, 3) * z, at + Vector2(1, 7) * z]), INK, 2.6, true)
			canvas.draw_polyline(PackedVector2Array([at + Vector2(1, -6) * z, at + Vector2(-1, 0) * z, at + Vector2(3, 3) * z]), GOLD, 1.1, true)
		"drowned_crypt":
			ellipse(canvas, at + Vector2(0, 11) * z, Vector2(15, 4) * z, Color("668c94"), 1.0)
			shape(canvas, [Vector2(-9, 11), Vector2(-9, -8), Vector2(-4, -12), Vector2(4, -12), Vector2(9, -8), Vector2(9, 11)], at, z, PAPER)
			canvas.draw_line(at + Vector2(5, -7) * z, at + Vector2(5, 8) * z, Color("a4977d"), 2.0, true)
			canvas.draw_line(at + Vector2(-4, -2) * z, at + Vector2(4, -2) * z, INK, 2.0)
			canvas.draw_line(at + Vector2(0, -6) * z, at + Vector2(0, 3) * z, INK, 1.5)
			canvas.draw_polyline(PackedVector2Array([at + Vector2(-8, 5) * z, at + Vector2(-3, 7) * z, at + Vector2(-5, 10) * z]), INK, 1.0, true)
		"bloodmoon_sanctuary":
			shape(canvas, [Vector2(0, -15), Vector2(9, -3), Vector2(6, 10), Vector2(-6, 10), Vector2(-9, -3)], at, z, Color("79556f"))
			shape(canvas, [Vector2(0, -12), Vector2(6, -3), Vector2(0, 7)], at, z, LILAC, 1.0)
			canvas.draw_line(at + Vector2(0, -12) * z, at + Vector2(0, 8) * z, INK, 1.0, true)
			shape(canvas, [Vector2(-10, 10), Vector2(-14, 3), Vector2(-9, 0), Vector2(-6, 10)], at, z, Color("79556f"), 1.3)

static func ground_detail(canvas: CanvasItem, style: String, at: Vector2, variant: int, scale_value: float) -> void:
	if style == "mourning_orchard":
		preload("res://scripts/rendering/actors/orchard_art.gd").detail(canvas, at, variant, scale_value)
		return
	# Small two-tone marks: texture at play scale, subordinate to actor outlines.
	var z := Vector2.ONE * scale_value
	var shade := ground_color(style).darkened(0.14)
	var light := ground_color(style).lightened(0.12)
	match style:
		"castle_ruin":
			match variant % 3:
				0:
					# Isolated worn paving, never a second grid over the playable tile.
					shape(canvas, [Vector2(-8, -3), Vector2(3, -5), Vector2(8, -1), Vector2(6, 4), Vector2(-7, 4)], at, z, light, 1.0)
					canvas.draw_polyline(PackedVector2Array([at + Vector2(1, -4) * z, at + Vector2(-1, 0) * z, at + Vector2(2, 3) * z]), shade, 1.1, true)
				1:
					canvas.draw_polyline(PackedVector2Array([at + Vector2(-7, -3) * z, at + Vector2(-2, -1) * z, at + Vector2(0, 4) * z, at + Vector2(6, 5) * z]), shade, 1.3, true)
					canvas.draw_line(at + Vector2(-2, -1) * z, at + Vector2(3, -4) * z, shade, 1.2, true)
				2:
					shape(canvas, [Vector2(-5, 2), Vector2(-4, -2), Vector2(0, -3), Vector2(4, 1), Vector2(2, 3)], at, z, light, 1.0)
					canvas.draw_line(at + Vector2(6, 4) * z, at + Vector2(9, 3) * z, shade, 1.4, true)
		"forest":
			if variant % 3 == 0:
				shape(canvas, [Vector2(-6, 1), Vector2(-1, -3), Vector2(6, 0), Vector2(1, 3)], at, z, light, 1.0)
				canvas.draw_line(at + Vector2(-3, 1) * z, at + Vector2(3, 0) * z, shade, 1.0, true)
			else:
				for tip in [Vector2(-5, -3), Vector2(-1, -6), Vector2(4, -3)]:
					canvas.draw_line(at + Vector2(0, 2) * z, at + tip * z, shade, 1.5, true)
		"ashen_forge":
			if variant % 3 == 0:
				shape(canvas, [Vector2(-5, 2), Vector2(-3, -3), Vector2(2, -4), Vector2(6, 1), Vector2(2, 3)], at, z, shade, 1.0)
				canvas.draw_line(at + Vector2(-2, -2) * z, at + Vector2(2, -2) * z, light, 1.2, true)
			else:
				canvas.draw_polyline(PackedVector2Array([at + Vector2(-7, -2) * z, at + Vector2(-2, 0) * z, at + Vector2(0, 4) * z, at + Vector2(5, 5) * z]), shade, 1.2, true)
				canvas.draw_line(at + Vector2(-2, 0) * z, at + Vector2(2, -3) * z, shade, 1.2, true)
		"drowned_crypt":
			canvas.draw_line(at + Vector2(-7, 1) * z, at + Vector2(6, 1) * z, shade, 1.4, true)
			canvas.draw_line(at + Vector2(-3, 4) * z, at + Vector2(3, 4) * z, light, 1.2, true)
			if variant % 3 == 0:
				for tip in [Vector2(-3, -5), Vector2(0, -7), Vector2(3, -4)]:
					canvas.draw_line(at, at + tip * z, shade, 1.2, true)
		"bloodmoon_sanctuary":
			if variant % 3 == 0:
				shape(canvas, [Vector2(-4, 1), Vector2(0, -5), Vector2(4, 1), Vector2(0, 3)], at, z, light, 1.0)
			else:
				canvas.draw_polyline(PackedVector2Array([at + Vector2(-6, 3) * z, at + Vector2(-2, 0) * z, at + Vector2(2, 0) * z, at + Vector2(6, -3) * z]), shade, 1.4, true)
				canvas.draw_line(at + Vector2(-2, 0) * z, at + Vector2(-3, -4) * z, shade, 1.2, true)

static func road_detail(canvas: CanvasItem, road: PackedVector2Array) -> void:
	# Broken inset edging keeps the central lane and exact joining mouths clear.
	for i in range(5, road.size() - 5, 6):
		var p := road[i]
		if p.length() < 40:
			continue
		var direction := (road[i + 1] - road[i - 1]).normalized()
		var normal := Vector2(-direction.y, direction.x)
		for side in [-1, 1]:
			var at: Vector2 = p + normal * side * 7.5
			canvas.draw_line(at - direction * 3.5, at + direction * 3.5, Color("b9a783"), 1.3, true)
		if i % 12 == 5:
			var at := p + normal * 5.0
			canvas.draw_line(at, at + normal * 4.0 + direction * 1.5, Color("a4977d"), 1.0, true)

static func enemy(canvas: CanvasItem, kind: String, at: Vector2, zoom: float) -> void:
	preload("res://scripts/rendering/actors/enemy_art.gd").draw(canvas, kind, at, zoom)
