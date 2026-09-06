class_name VigilTerrainGrid
extends Node2D

const LINE_WIDTH := 6.0

var view := Rect2()

func synchronize(world_view: Rect2) -> void:
	if view == world_view:
		return
	view = world_view
	queue_redraw()

func _draw() -> void:
	# One world-aligned lattice covers owned and future territory alike. Only
	# visible rows/columns are drawn, so work stays bounded as the world grows.
	var bounds := view.grow(LINE_WIDTH * 0.5)
	var half_tile := Balance.TILE * 0.5
	var first := Vector2i(ceil((bounds.position.x + half_tile) / Balance.TILE), ceil((bounds.position.y + half_tile) / Balance.TILE))
	var last := Vector2i(floor((bounds.end.x + half_tile) / Balance.TILE), floor((bounds.end.y + half_tile) / Balance.TILE))
	for column in range(first.x, last.x + 1):
		var x := column * Balance.TILE - half_tile - LINE_WIDTH * 0.5
		draw_rect(Rect2(Vector2(x, bounds.position.y), Vector2(LINE_WIDTH, bounds.size.y)), VigilTerrainArt.INK)
	for row in range(first.y, last.y + 1):
		var y := row * Balance.TILE - half_tile - LINE_WIDTH * 0.5
		draw_rect(Rect2(Vector2(bounds.position.x, y), Vector2(bounds.size.x, LINE_WIDTH)), VigilTerrainArt.INK)
