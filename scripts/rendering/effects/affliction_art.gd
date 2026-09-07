extends RefCounted

const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const VENOM := Color("a6c875")
const FROST := Color("96d6e6")

# Any recipient of the shared non-fire DOT component uses the same cue.
# Read live status only: expiry, replacement and pooling need no visual timers.
static func poisoned(enemy: Dictionary, time: float) -> bool:
	for status in enemy.get("gear_status", {}).values():
		if status.get("type", "") == "dot" and not status.get("fire", false) and status.get("damage", 0.0) > 0.0 and status.get("until", 0.0) > time:
			return true
	return false

static func draw(canvas: CanvasItem, enemy: Dictionary, at: Vector2, zoom: float, time: float) -> void:
	if enemy.get("slow_until", 0.0) > time:
		draw_frost(canvas, enemy, at, zoom, time)
	if not poisoned(enemy, time):
		return
	canvas.draw_arc(at + Vector2(0, 8) * zoom, 13 * zoom, 0.1, PI - 0.1, 16, VENOM, 2 * zoom, true)
	for index in range(3):
		var phase := fposmod(time * 0.75 + index / 3.0 + float(enemy.get("id", 0)) * 0.17, 1.0)
		var offset := Vector2(-15 if index % 2 == 0 else 15, 5 - phase * 25)
		var radius := (2.0 + sin(phase * PI)) * zoom
		Art.disk(canvas, at + offset * zoom, radius, VENOM, zoom)
		canvas.draw_circle(at + (offset + Vector2(-0.6, -0.7)) * zoom, 0.7 * zoom, Art.PAPER)

# Shared slow-status presentation: no tower/type checks or retained instance state.
static func draw_frost(canvas: CanvasItem, enemy: Dictionary, at: Vector2, zoom: float, time: float) -> void:
	var scale := Vector2.ONE * zoom
	# Low ice facets leave the recipient's face and silhouette readable.
	for side in [-1, 1]:
		Art.shape(canvas, [Vector2(side * 5, 11), Vector2(side * 8, 4), Vector2(side * 11, 8), Vector2(side * 15, 5), Vector2(side * 13, 13)], at, scale, FROST, zoom)
		canvas.draw_line(at + Vector2(side * 8, 7) * zoom, at + Vector2(side * 7, 10) * zoom, Art.PAPER, zoom, true)
	# Crystals rise like poison bubbles, with angular facets and a gentle side drift.
	for index in range(3):
		var phase := fposmod(time * 0.65 + index / 3.0 + float(enemy.get("id", 0)) * 0.17, 1.0)
		var side := -1.0 if index % 2 == 0 else 1.0
		var offset := Vector2(side * (16.0 + sin(phase * PI) * 2.0), 5 - phase * 25)
		var radius := 1.5 + sin(phase * PI) * 1.5
		var center := at + offset * zoom
		Art.shape(canvas, [Vector2(0, -radius * 1.5), Vector2(radius, 0), Vector2(0, radius * 1.5), Vector2(-radius, 0)], center, scale, FROST, zoom)
		canvas.draw_line(center + Vector2(0, -radius * 0.8) * zoom, center + Vector2(0, radius * 0.4) * zoom, Art.PAPER, 0.8 * zoom, true)
