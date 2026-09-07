extends Control
## Stateless title-page illustrations composed from the native game art library.
## Decorative controls never start a simulation, own input, or access saves.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
const DISTANT := Color("52645a")
const HILL := Color("71816a")
const RIDGE := Color("a6b79b")
const SHADOW := Color("1b2a27")
@export_enum("seal", "landscape", "rule") var illustration := "seal"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if illustration != "landscape":
		ornament(illustration == "seal")
		return
	var zoom := minf(size.x / 480.0, size.y / 260.0)
	draw_set_transform((size - Vector2(480, 260) * zoom) * 0.5, 0, Vector2.ONE * zoom)
	landscape()

func ornament(seal: bool) -> void:
	var center := size * 0.5
	var reach := 64.0 if seal else 44.0
	for side in [-1, 1]:
		draw_line(center + Vector2(side * 18, 0), center + Vector2(side * reach, 0), UI.PANEL, UI.OUTLINE)
	var radius := 9.0 if seal else 4.0
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.55, 0), center + Vector2(0, radius), center - Vector2(radius * 0.55, 0)])
	draw_colored_polygon(points, Art.MINT if seal else Art.GOLD)
	if seal:
		draw_line(center + Vector2(0, -5), center + Vector2(0, 4), SHADOW, 2)

func shape(points: Array, color: Color, stroke: float = 2.5) -> void:
	Art.shape(self, points, Vector2.ZERO, Vector2.ONE, color, stroke)

func pine(at: Vector2, height: float, color: Color) -> void:
	var width := height * 0.32
	var points := [Vector2(0, -height), Vector2(width * 0.62, -height * 0.58), Vector2(width * 0.3, -height * 0.58), Vector2(width, -height * 0.2), Vector2(4, -height * 0.2), Vector2(4, 0), Vector2(-4, 0), Vector2(-4, -height * 0.2), Vector2(-width, -height * 0.2), Vector2(-width * 0.3, -height * 0.58), Vector2(-width * 0.62, -height * 0.58)]
	Art.shape(self, points, at, Vector2.ONE, color, 2.5)

func landscape() -> void:
	# The moon, far ridge and ruined wall sit behind the inhabited sanctuary.
	Art.disk(self, Vector2(336, 57), 42, Art.PAPER, 2.5)
	shape([Vector2(4,139),Vector2(68,80),Vector2(119,103),Vector2(172,61),Vector2(246,108),Vector2(305,88),Vector2(366,117),Vector2(439,86),Vector2(476,126),Vector2(455,183),Vector2(30,183)], DISTANT)
	for item in [[Vector2(78,119),43.0],[Vector2(150,110),29.0],[Vector2(217,127),34.0],[Vector2(423,125),38.0]]:
		pine(item[0], item[1], DISTANT)
	shape([Vector2(236,127),Vector2(246,85),Vector2(258,85),Vector2(258,77),Vector2(270,77),Vector2(270,101),Vector2(301,106),Vector2(307,83),Vector2(320,83),Vector2(320,119),Vector2(365,128),Vector2(387,152),Vector2(236,167)], HILL)
	# Open ground and a winding pale road lead the eye to the actual core artwork.
	shape([Vector2(8,183),Vector2(78,136),Vector2(169,145),Vector2(245,167),Vector2(292,128),Vector2(371,126),Vector2(471,185),Vector2(418,236),Vector2(294,251),Vector2(178,238),Vector2(79,250),Vector2(18,222)], HILL)
	shape([Vector2(236,179),Vector2(286,133),Vector2(364,128),Vector2(412,164),Vector2(353,178),Vector2(308,165),Vector2(268,192)], RIDGE)
	var road := PackedVector2Array([Vector2(331,156),Vector2(300,178),Vector2(226,182),Vector2(189,211),Vector2(236,228),Vector2(221,246)])
	draw_polyline(road, Art.INK, 18, true)
	draw_polyline(road, Art.ROAD, 13, true)
	Art.portal(self, Vector2(331,151), 1.08, true)
	# A solitary watchtower holds the left ridge, distinct from the old crest.
	shape([Vector2(87,171),Vector2(106,148),Vector2(151,153),Vector2(163,182),Vector2(139,199),Vector2(91,191)], RIDGE)
	Art.sentinel(self, "rapid", Vector2(125,163), 1.55, 3)
	Art.scenery(self, "drowned_crypt", Vector2(271,202), 25)
	for item in [[Vector2(45,176),84.0],[Vector2(72,198),70.0],[Vector2(425,192),105.0],[Vector2(451,214),83.0]]:
		pine(item[0], item[1], SHADOW)
	# Broken foreground edges keep this a landscape illustration, not a map card.
	shape([Vector2(12,221),Vector2(70,209),Vector2(105,224),Vector2(164,228),Vector2(176,246),Vector2(79,250),Vector2(18,236)], SHADOW)
	shape([Vector2(294,247),Vector2(326,222),Vector2(365,226),Vector2(412,211),Vector2(468,211),Vector2(433,238),Vector2(353,253)], SHADOW)
