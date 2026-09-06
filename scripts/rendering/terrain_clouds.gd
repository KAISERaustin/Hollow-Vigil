extends Node2D

const CLOUDS := preload("res://assets/terrain/unknown-clouds.png")
const TINT := Color(0.60, 0.62, 0.68)

var view := Rect2()

func synchronize(world_view: Rect2) -> void:
	if view == world_view:
		return
	view = world_view
	queue_redraw()

func _draw() -> void:
	# Opaque cloud tiles sit below owned terrain and the original grid. Revealing
	# a region naturally covers its fog, with no changes to saves or map logic.
	var half_tile := Vector2.ONE * Balance.TILE * 0.5
	var first := Vector2i(floor((view.position.x + half_tile.x) / Balance.TILE), floor((view.position.y + half_tile.y) / Balance.TILE))
	var last := Vector2i(floor((view.end.x + half_tile.x) / Balance.TILE), floor((view.end.y + half_tile.y) / Balance.TILE))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var rect := Rect2(Vector2(x, y) * Balance.TILE - half_tile, Vector2.ONE * Balance.TILE)
			# Mirrored repeats meet at identical texture edges, even at negative
			# coordinates, and avoid a conspicuous identical stamp in every cell.
			if posmod(x, 2) == 1:
				rect.size.x = -rect.size.x
			if posmod(y, 2) == 1:
				rect.size.y = -rect.size.y
			draw_texture_rect(CLOUDS, rect, false, TINT)
