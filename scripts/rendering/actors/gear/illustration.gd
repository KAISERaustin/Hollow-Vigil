extends RefCounted

## A shared ink-and-parchment construction kit, in a 70-unit design square.
## One short-lived context per draw; content definitions hold no CanvasItem.
const Palette = preload("res://scripts/rendering/terrain/terrain_art.gd")
const INK := Palette.INK
const PAPER := Palette.PAPER
const GOLD := Palette.GOLD
const MINT := Palette.MINT
const CORAL := Palette.CORAL
const LILAC := Palette.LILAC
const STONE := Color("a5ada2")
const IRON := Color("424e50")
const WOOD := Color("8c795c")
var canvas: CanvasItem
var origin: Vector2
var scale_value: float

func _init(target: CanvasItem, at: Vector2, zoom: float) -> void:
	canvas = target
	origin = at
	scale_value = zoom * 0.4

func points(coords: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(0, coords.size(), 2):
		result.append(origin + Vector2(coords[index], coords[index + 1]) * scale_value)
	return result

func poly(coords: Array, color: Color, width: float = 2.6) -> void:
	Palette.polygon(canvas, points(coords), color, width * scale_value)

func line(coords: Array, color: Color = INK, width: float = 1.8) -> void:
	canvas.draw_polyline(points(coords), color, width * scale_value, true)

func oval(x: float, y: float, rx: float, ry: float, color: Color, width: float = 2.6) -> void:
	Palette.ellipse(canvas, origin + Vector2(x, y) * scale_value, Vector2(rx, ry) * scale_value, color, width * scale_value)

func gem(x: float, y: float, w: float, h: float, color: Color) -> void:
	poly([x,y-h,x+w,y,x,y+h,x-w,y], color, 1.8)
	poly([x,y-h+2,x,y+h-2,x-w+2,y], PAPER, 0)

func rivet(x: float, y: float) -> void:
	oval(x, y, 1.8, 1.8, GOLD, 1.2)

func leaf(x: float, y: float, side: float, color: Color) -> void:
	poly([x,y,x+side*2,y-9,x+side*13,y-14,x+side*12,y-5,x+side*6,y], color, 2)
	line([x+side*2,y-2,x+side*9,y-10], INK, 1.3)

func link(x: float, y: float, color: Color, horizontal: bool = false) -> void:
	if horizontal:
		poly([x-9,y-3,x-4,y-6,x+7,y-5,x+10,y,x+6,y+5,x-6,y+5,x-10,y], color, 2)
		line([x-5,y,x+5,y], INK, 2.2)
	else:
		poly([x-4,y-8,x+3,y-9,x+6,y-4,x+5,y+7,x,y+10,x-5,y+6,x-6,y-3], color, 2)
		line([x,y-4,x,y+5], INK, 2.2)

func skull(x: float, y: float, color: Color = PAPER) -> void:
	poly([x-7,y-7,x+5,y-8,x+9,y-3,x+6,y+4,x+4,y+8,x-4,y+8,x-5,y+3,x-9,y], color, 2)
	poly([x-5,y-3,x-1,y-2,x-3,y+1], INK, 0)
	poly([x+2,y-3,x+6,y-4,x+4,y], INK, 0)
	line([x-2,y+5,x+3,y+5], INK, 1.4)
