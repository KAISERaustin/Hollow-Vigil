extends RefCounted

## Shared inked sigils for afflicted enemies and empowered tower foundations.
## Animation is derived from the simulation clock, with no retained effect state.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const HEX := Color("c58cdb")
const DEEP := Color("80549f")

static func active(recipient: Dictionary, time: float) -> bool:
	for status in recipient.get("gear_status", {}).values():
		if status.get("type", "") == "expose" and status.get("strength", 0.0) > 0.0 and status.get("until", 0.0) > time:
			return true
	return false

static func rune(canvas: CanvasItem, at: Vector2, zoom: float, size: float = 3.0) -> void:
	Art.shape(canvas, [Vector2(0, -size * 1.5), Vector2(size, 0), Vector2(0, size * 1.5), Vector2(-size, 0)], at, Vector2.ONE * zoom, HEX, zoom)
	canvas.draw_line(at + Vector2(0, -size * 0.7) * zoom, at + Vector2(0, size * 0.7) * zoom, Art.INK, zoom, true)
	canvas.draw_line(at + Vector2(-size - 1, 0) * zoom, at + Vector2(size + 1, 0) * zoom, Art.INK, zoom, true)

static func enemy(canvas: CanvasItem, recipient: Dictionary, at: Vector2, zoom: float, time: float) -> void:
	if not active(recipient, time): return
	var phase := time * 1.8 + float(recipient.get("id", 0)) * 0.17
	# Poison/ice's low cue and rising side shapes, with a distinct occult silhouette.
	var eye := at + Vector2(0, -27 - sin(phase) * 1.5) * zoom
	Art.shape(canvas, [Vector2(-9, 0), Vector2(-4, -5), Vector2(4, -5), Vector2(9, 0), Vector2(4, 5), Vector2(-4, 5)], eye, Vector2.ONE * zoom, HEX, 1.5 * zoom)
	Art.disk(canvas, eye, 3.0 * zoom, DEEP, zoom)
	canvas.draw_line(eye + Vector2(0, -2) * zoom, eye + Vector2(0, 2) * zoom, Art.PAPER, zoom, true)
	for side in [-1, 1]:
		canvas.draw_line(eye + Vector2(side * 6, -4) * zoom, eye + Vector2(side * 8, -8) * zoom, Art.INK, 1.5 * zoom, true)
	base(canvas, at + Vector2(0, 6) * zoom, zoom * 0.72, time)
	for index in range(3):
		var rise := fposmod(time * 0.6 + index / 3.0 + float(recipient.get("id", 0)) * 0.17, 1.0)
		var side := -1.0 if index % 2 == 0 else 1.0
		rune(canvas, at + Vector2(side * (18.0 + sin(rise * PI)), 8 - rise * 29) * zoom, zoom, 2.2 + sin(rise * PI) * 0.6)

static func base(canvas: CanvasItem, at: Vector2, zoom: float, time: float) -> void:
	# A broken, flattened ring sits at ground level without covering tower artwork.
	var pulse := 0.5 + 0.5 * sin(time * 1.8)
	for side in [0, 1]:
		var points := PackedVector2Array()
		for step in range(13):
			var angle: float = side * PI + 0.22 + float(step) / 12.0 * (PI - 0.44)
			points.append(at + Vector2(cos(angle) * 24, sin(angle) * 7 + 9) * zoom)
		canvas.draw_polyline(points, Art.INK, 3.0 * zoom, true)
		canvas.draw_polyline(points, DEEP.lerp(HEX, pulse * 0.45), 1.5 * zoom, true)
	for side in [-1, 1]:
		rune(canvas, at + Vector2(side * 23, 9) * zoom, zoom, 2.0)
