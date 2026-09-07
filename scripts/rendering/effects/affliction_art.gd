extends RefCounted

const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const VENOM := Color("a6c875")

# Any recipient of the shared non-fire DOT component uses the same cue.
# Read live status only: expiry, replacement and pooling need no visual timers.
static func poisoned(enemy: Dictionary, time: float) -> bool:
	for status in enemy.get("gear_status", {}).values():
		if status.get("type", "") == "dot" and not status.get("fire", false) and status.get("damage", 0.0) > 0.0 and status.get("until", 0.0) > time:
			return true
	return false

static func draw(canvas: CanvasItem, enemy: Dictionary, at: Vector2, zoom: float, time: float) -> void:
	if not poisoned(enemy, time):
		return
	canvas.draw_arc(at + Vector2(0, 8) * zoom, 13 * zoom, 0.1, PI - 0.1, 16, VENOM, 2 * zoom, true)
	for index in range(3):
		var phase := fposmod(time * 0.75 + index / 3.0 + float(enemy.get("id", 0)) * 0.17, 1.0)
		var offset := Vector2(-15 if index % 2 == 0 else 15, 5 - phase * 25)
		var radius := (2.0 + sin(phase * PI)) * zoom
		Art.disk(canvas, at + offset * zoom, radius, VENOM, zoom)
		canvas.draw_circle(at + (offset + Vector2(-0.6, -0.7)) * zoom, 0.7 * zoom, Art.PAPER)
