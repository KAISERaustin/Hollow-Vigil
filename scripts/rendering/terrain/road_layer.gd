extends Node2D

# Authored routes cross terrain chunks. Draw them once without tile clipping
# so fractional camera transforms cannot cut strips out of their fill or ink.
var roads: Array[PackedVector2Array] = []

func configure(routes: Array) -> void:
	roads.clear()
	for route in routes:
		roads.append(PackedVector2Array(route))
	queue_redraw()

func _draw() -> void:
	draw_roads(self, roads)

static func draw_roads(canvas: CanvasItem, routes: Array[PackedVector2Array]) -> void:
	# All outlines precede all fills, including at forks and crossings.
	for road in routes:
		canvas.draw_polyline(road, VigilTerrainArt.INK, 28.0, true)
	for road in routes:
		canvas.draw_polyline(road, VigilTerrainArt.ROAD, 23.0, true)
	for road in routes:
		VigilTerrainArt.road_detail(canvas, road)
