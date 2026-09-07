extends RefCounted

const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const Upgrades = preload("res://scripts/rendering/actors/portal_upgrade_art.gd")
const Content = preload("res://scripts/content/registry.gd")

# The same flat fills, ink edges and cut-stone geometry as sentinels and scenery.
# No particle nodes or animation: markers remain legible in reduced-motion mode.
static func draw(canvas: CanvasItem, style: String, at: Vector2, zoom: float, traffic: int = 0, unlocks: Array = []) -> void:
	var portal := Content.portal(style)
	if portal == null:
		portal = Content.portal("forest")
	var parts := portal.visual_parts(traffic, unlocks)
	Upgrades.structure(canvas, style, at, zoom, parts.structure)
	draw_base(canvas, style, at, zoom)
	Upgrades.details(canvas, at, zoom, parts)

static func draw_core(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	# The receiving portal shares the masonry kit, but has no spawn upgrades.
	Upgrades.structure(canvas, "core", at, zoom, ["foundation"])
	Art.portal(canvas, at, zoom, true)

static func draw_base(canvas: CanvasItem, style: String, at: Vector2, zoom: float) -> void:
	if style == "mourning_orchard":
		preload("res://scripts/rendering/actors/orchard_art.gd").portal(canvas, at, zoom)
		return
	if style == "castle_ruin":
		dungeon_portal(canvas, at, zoom)
		return
	var z := Vector2.ONE * zoom
	var w := 2.5 * zoom
	var accent := Art.ground_color(style).lightened(0.12)
	Art.ellipse(canvas, at + Vector2(0, 16) * z, Vector2(29, 8) * z, Art.INK, 0)
	Art.shape(canvas, [Vector2(-25, 12), Vector2(-23, -22), Vector2(-12, -39), Vector2(12, -39), Vector2(23, -22), Vector2(25, 12)], at, z, accent, w)
	Art.shape(canvas, [Vector2(-15, 11), Vector2(-14, -19), Vector2(-7, -29), Vector2(7, -29), Vector2(14, -19), Vector2(15, 11)], at, z, Art.INK, w)
	# A jagged pale seam reads as a rip rather than an empty doorway.
	Art.shape(canvas, [Vector2(3, -23), Vector2(-5, -8), Vector2(0, -5), Vector2(-3, 7), Vector2(7, -9), Vector2(2, -11)], at, z, accent, 0)
	match style:
		"ashen_forge":
			for side in [-1, 1]:
				Art.shape(canvas, [Vector2(side * 16, -24), Vector2(side * 28, -21), Vector2(side * 28, -9), Vector2(side * 17, -7)], at, z, Art.CORAL, w)
				Art.disk(canvas, at + Vector2(side * 22, -16) * z, 2 * zoom, Art.PAPER, zoom)
				Art.shape(canvas, [Vector2(side * 17, -3), Vector2(side * 28, 0), Vector2(side * 26, 13), Vector2(side * 17, 10)], at, z, Art.CORAL, w)
			shield(canvas, at + Vector2(0, -35) * z, zoom * 1.2)
		"drowned_crypt":
			for side in [-1, 1]:
				Art.shape(canvas, [Vector2(side * 18, 10), Vector2(side * 29, 5), Vector2(side * 31, -6), Vector2(side * 25, -14), Vector2(side * 18, -12), Vector2(side * 23, -7), Vector2(side * 22, -1), Vector2(side * 16, 2)], at, z, Art.MINT, w)
				canvas.draw_line(at + Vector2(side * 19, -24) * z, at + Vector2(side * 22, -18) * z, Art.INK, 1.5 * zoom, true)
			current(canvas, at + Vector2(0, -35) * z, zoom)
		"bloodmoon_sanctuary":
			for side in [-1, 1]:
				Art.shape(canvas, [Vector2(side * 18, 11), Vector2(side * 28, 7), Vector2(side * 29, -15), Vector2(side * 22, -8)], at, z, Art.LILAC, w)
				Art.shape(canvas, [Vector2(side * 19, -23), Vector2(side * 26, -37), Vector2(side * 15, -31)], at, z, Art.LILAC, w)
			moon(canvas, at + Vector2(0, -37) * z, zoom * 1.3)
		_:
			for side in [-1, 1]:
				Art.shape(canvas, [Vector2(side * 19, 10), Vector2(side * 22, -5), Vector2(side * 30, -12), Vector2(side * 24, 2), Vector2(side * 28, 10)], at, z, Color("567456"), w)
			Art.shape(canvas, [Vector2(-7, -35), Vector2(0, -44), Vector2(7, -35), Vector2(0, -30)], at, z, Art.PAPER, w)
	Art.shape(canvas, [Vector2(-27, 11), Vector2(27, 11), Vector2(24, 17), Vector2(-24, 17)], at, z, Art.PAPER, w)

# Campaign has authored waves rather than purchased attunements. Reuse the same
# kit, but show only ordinary inhabitants actually assigned to this lane/wave.
static func wave_parts(style: String, groups: Array, lane: int) -> Dictionary:
	var visuals = preload("res://scripts/content/catalogs/portal_visuals.gd")
	var inhabitants: Array = []
	for group in groups:
		if int(group[2]) == lane and int(group[1]) > 0 and visuals.ORNAMENTS.has(group[0]) and group[0] not in inhabitants:
			inhabitants.append(group[0])
	var attachments: Array = Content.portal(style).rule("components", [])
	for attachment in attachments:
		if attachment.slot == "appearance":
			var config: Dictionary = attachment.config.duplicate(true)
			config.order = inhabitants
			config.ornaments = visuals.ORNAMENTS
			return attachment.component.parts(0, inhabitants, config)
	return {"structure": [], "runes": 0, "ornaments": []}

static func draw_wave(canvas: CanvasItem, style: String, at: Vector2, zoom: float, groups: Array, lane: int) -> void:
	draw_base(canvas, style, at, zoom)
	Upgrades.details(canvas, at, zoom, wave_parts(style, groups, lane))

static func shield(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	Art.shape(canvas, [Vector2(-6, -5), Vector2(6, -5), Vector2(5, 2), Vector2(0, 7), Vector2(-5, 2)], at, Vector2.ONE * zoom, Art.GOLD, 1.5 * zoom)
	canvas.draw_line(at + Vector2(0, -2) * zoom, at + Vector2(0, 3) * zoom, Art.INK, zoom, true)

static func current(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	for y in [-3, 3]:
		Art.shape(canvas, [Vector2(-7, y - 2), Vector2(1, y - 2), Vector2(6, y), Vector2(1, y + 2), Vector2(-7, y + 2), Vector2(-3, y)], at, Vector2.ONE * zoom, Art.MINT, zoom)

static func moon(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	Art.shape(canvas, [Vector2(3, -7), Vector2(-3, -6), Vector2(-7, -1), Vector2(-5, 5), Vector2(1, 7), Vector2(6, 3), Vector2(0, 3), Vector2(-2, -1), Vector2(-1, -4)], at, Vector2.ONE * zoom, Art.LILAC, 1.5 * zoom)

static func enemy_mark(canvas: CanvasItem, style: String, at: Vector2, zoom: float) -> void:
	# Center overhead, leaving room below for the health bar and silhouette.
	var badge := at + Vector2(0, -33) * zoom
	match style:
		"ashen_forge": shield(canvas, badge, zoom * 0.7)
		"drowned_crypt": current(canvas, badge, zoom * 0.7)
		"bloodmoon_sanctuary": moon(canvas, badge, zoom * 0.7)

static func dungeon_portal(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	var z := Vector2.ONE * zoom
	Art.ellipse(canvas, at + Vector2(0, 5) * z, Vector2(39, 28) * z, Color("363340"), 3 * zoom)
	Art.ellipse(canvas, at, Vector2(38, 27) * z, Color("b0a8b7"), 2.5 * zoom)
	Art.ellipse(canvas, at, Vector2(29, 19) * z, Color("15131f"), 2 * zoom)
	Art.ellipse(canvas, at + Vector2(0, 3) * z, Vector2(21, 12) * z, Color("292235"), 0)
	Art.ellipse(canvas, at + Vector2(0, 5) * z, Vector2(15, 8) * z, Color("090b12"), 0)
	for i in range(10):
		var direction := Vector2.from_angle(i * TAU / 10.0)
		canvas.draw_line(at + direction * Vector2(30, 20) * z, at + direction * Vector2(37, 26) * z, Art.INK, 1.5 * zoom, true)
	for side in [-1, 1]:
		Art.shape(canvas, [Vector2(side*33,-8),Vector2(side*37,-17),Vector2(side*41,-8),Vector2(side*37,-2)], at,z,Art.LILAC,1.5*zoom)
	canvas.draw_arc(at, 12 * zoom, 3.5, 5.7, 16, Art.LILAC, 1.5 * zoom, true)
