extends Node2D

const Areas = preload("res://scripts/world/hidden_areas.gd")
# Temporary art-review switch. Disable to conceal placeholders beneath fog.
const SHOW_PLACEHOLDERS := true
var cells: Array[Vector2i] = []
var signature: Array = []

func synchronize(state: VigilState, view: Rect2) -> void:
	visible = SHOW_PLACEHOLDERS
	var first := Areas.sector_for(Vector2i((view.position / Balance.TILE).floor()) - Vector2i.ONE)
	var last := Areas.sector_for(Vector2i((view.end / Balance.TILE).ceil()) + Vector2i.ONE)
	var next_signature := [state, state.data.seed, state.terrain_revision, first, last]
	if signature == next_signature:
		return
	signature = next_signature
	cells.clear()
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for cell in Areas.cluster(Vector2i(x, y), int(state.data.seed)):
				if not state.data.regions.has(VigilWorld.key(cell)):
					cells.append(cell)
	queue_redraw()

func _draw() -> void:
	for cell in cells:
		var corner := Vector2(cell) * Balance.TILE - Vector2.ONE * Balance.TILE * 0.5
		# Keep small stone geometry local even at distant map coordinates.
		draw_set_transform(corner)
		# Opaque ground covers the cloud tile exactly, like owned terrain.
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * Balance.TILE), Color("666b73"))
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(("placeholder-stone:" + str(cell)).hash())
		for row in range(5):
			for column in range(5):
				var p := Vector2(column * 60, row * 60)
				var inset := rng.randf_range(3, 7)
				var shape := PackedVector2Array([p + Vector2(inset + 6, inset), p + Vector2(54, inset + 2), p + Vector2(58, 46), p + Vector2(48, 57), p + Vector2(inset, 54), p + Vector2(inset, 12)])
				var shade := rng.randf_range(0.43, 0.54)
				draw_colored_polygon(shape, Color(shade, shade + 0.015, shade + 0.03))
				shape.append(shape[0])
				draw_polyline(shape, Color("41464e"), 2.5, true)
				draw_line(shape[0] + Vector2(2, 3), shape[1] + Vector2(-2, 3), Color("969ba2"), 2.0, true)
