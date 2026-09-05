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
	"forest": Color("95aa83"),
	"ashen_forge": Color("bb8c76"),
	"drowned_crypt": Color("7fa6aa"),
	"bloodmoon_sanctuary": Color("ae879b")
}

static func ground_color(style: String) -> Color:
	return BIOME_COLORS.get(style, BIOME_COLORS.forest)

static func polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, width: float = 2.0) -> void:
	canvas.draw_colored_polygon(points, fill)
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
	disk(canvas, at, 19.0, PAPER)

static func portal(canvas: CanvasItem, at: Vector2, zoom: float, core: bool) -> void:
	var accent := MINT if core else LILAC
	var center := at + Vector2(0, -5) * zoom
	ellipse(canvas, center, Vector2(23, 29) * zoom, accent, 2.5 * zoom)
	ellipse(canvas, center, Vector2(14, 20) * zoom, INK, 2.0 * zoom)
	canvas.draw_line(center + Vector2(-17, -9) * zoom, center + Vector2(-17, 4) * zoom, PAPER, 2.5 * zoom, true)

static func sentinel(canvas: CanvasItem, kind: String, at: Vector2, zoom: float) -> void:
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
		_:
			shape(canvas, [Vector2(-13, 7), Vector2(-10, -29), Vector2(0, -43), Vector2(10, -29), Vector2(13, 7)], at, z, LILAC, w)
			shape(canvas, [Vector2(0, -25), Vector2(5, -18), Vector2(0, -11), Vector2(-5, -18)], at, z, INK, zoom)
	shape(canvas, [Vector2(-17, 6), Vector2(17, 6), Vector2(17, 12), Vector2(-17, 12)], at, z, PAPER, w)

static func scenery(canvas: CanvasItem, style: String, at: Vector2, extent: float) -> void:
	var z := Vector2.ONE * extent / 30.0
	match style:
		"forest":
			canvas.draw_line(at + Vector2(0, 5) * z, at + Vector2(0, 13) * z, INK, 2.0)
			shape(canvas, [Vector2(0, -15), Vector2(12, 7), Vector2(-12, 7)], at, z, Color("567456"))
		"ashen_forge":
			shape(canvas, [Vector2(-13, 8), Vector2(-9, -5), Vector2(1, -10), Vector2(12, -2), Vector2(14, 8)], at, z, Color("80685d"))
		"drowned_crypt":
			shape(canvas, [Vector2(-9, 11), Vector2(-9, -8), Vector2(-4, -12), Vector2(4, -12), Vector2(9, -8), Vector2(9, 11)], at, z, PAPER)
			canvas.draw_line(at + Vector2(-4, -2) * z, at + Vector2(4, -2) * z, INK, 2.0)
		"bloodmoon_sanctuary":
			shape(canvas, [Vector2(0, -15), Vector2(9, -3), Vector2(6, 10), Vector2(-6, 10), Vector2(-9, -3)], at, z, Color("79556f"))

static func enemy(canvas: CanvasItem, kind: String, at: Vector2, zoom: float) -> void:
	var z := Vector2.ONE * zoom
	match kind:
		"basic":
			disk(canvas, at + Vector2(0, -2) * z, 8.0 * zoom, PAPER, 2.0 * zoom)
		"fast":
			shape(canvas, [Vector2(0, -12), Vector2(8, -3), Vector2(8, 7), Vector2(0, 3), Vector2(-8, 7), Vector2(-8, -3)], at, z, MINT, 2.0 * zoom)
		_:
			shape(canvas, [Vector2(-10, -6), Vector2(-5, -11), Vector2(5, -11), Vector2(10, -6), Vector2(10, 8), Vector2(-10, 8)], at, z, CORAL, 2.0 * zoom)
	for x in [-3, 3]:
		canvas.draw_circle(at + Vector2(x, -3) * z, 1.3 * zoom, INK)
