extends RefCounted
## Shared original tower action artwork for world controls and management cards.
const UI = preload("res://scripts/ui/shared/interface.gd")

static func draw(button: Button, action: String, equipment_kind: String = "", upgrade_maxed: bool = false, pending_tower: String = "") -> void:
	var center := button.size * 0.5
	var color := UI.TEXT
	if action == "equipment":
		if equipment_kind != "":
			preload("res://scripts/rendering/actors/relic_art.gd").draw(button, equipment_kind, center)
		else:
			button.draw_polyline(PackedVector2Array([center + Vector2(0,-13), center + Vector2(11,0), center + Vector2(0,13), center + Vector2(-11,0), center + Vector2(0,-13)]), color, 2, true)
			button.draw_line(center + Vector2(-5,0), center + Vector2(5,0), color, 2, true)
			button.draw_line(center + Vector2(0,-5), center + Vector2(0,5), color, 2, true)
	elif action == "info":
		button.draw_arc(center, 11, 0, TAU, 40, color, 3, true)
		button.draw_circle(center + Vector2(0, -5), 2, color)
		button.draw_line(center + Vector2(0, -1), center + Vector2(0, 6), color, 3, true)
	elif action == "upgrade":
		if upgrade_maxed:
			button.draw_arc(center + Vector2(0, -4), 7, PI, TAU, 24, UI.MUTED, 3, true)
			button.draw_rect(Rect2(center + Vector2(-10, -4), Vector2(20, 17)), UI.MUTED)
			button.draw_circle(center + Vector2(0, 2), 2, UI.PANEL)
			button.draw_line(center + Vector2(0, 3), center + Vector2(0, 7), UI.PANEL, 2, true)
			return
		if pending_tower != "":
			button.draw_polyline(PackedVector2Array([center + Vector2(-10, 0), center + Vector2(-3, 7), center + Vector2(11, -8)]), color, 3, true)
			return
		for y in [-3, 5]:
			button.draw_polyline(PackedVector2Array([center + Vector2(-9, y + 3), center + Vector2(0, y - 5), center + Vector2(9, y + 3)]), color, 3, true)
	elif action == "target":
		button.draw_arc(center, 10, 0, TAU, 40, color, 2, true)
		button.draw_circle(center, 3, color)
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			button.draw_line(center + direction * 7, center + direction * 15, color, 2, true)
	elif action == "move":
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var tip: Vector2 = center + direction * 12
			var side: Vector2 = direction.orthogonal() * 4
			button.draw_line(center, tip, color, 2, true)
			button.draw_polyline(PackedVector2Array([tip - direction * 5 + side, tip, tip - direction * 5 - side]), color, 2, true)
	else:
		button.draw_arc(center, 11, 0, TAU, 40, color, 3, true)
		button.draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), color, 3, true)

