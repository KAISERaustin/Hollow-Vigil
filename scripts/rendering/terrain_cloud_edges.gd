extends Node2D

const Clouds = preload("res://scripts/rendering/terrain_clouds.gd")
const OUTLINE := Color("10151c")
const OUTLINE_WIDTH := 2.0
const LOBES := 7
const LOBE_STEPS := 16

var borders: Array[Dictionary] = []
var borders_by_region: Dictionary = {}
var view := Rect2()
var model: VigilState
var revision := -1

func synchronize(state: VigilState, world_view: Rect2) -> void:
	var changed := model != state or revision != state.terrain_revision
	if changed:
		model = state
		revision = state.terrain_revision
		borders.clear()
		borders_by_region.clear()
		for id in state.data.regions:
			var cell := VigilWorld.coord(id)
			var directions: Array[Vector2] = []
			for direction in VigilWorld.DIRS:
				if not state.data.regions.has(VigilWorld.key(cell + direction)) and not preload("res://scripts/world/hidden_areas.gd").reserved(cell + direction, int(state.data.seed), state.data.regions):
					directions.append(Vector2(direction))
			if not directions.is_empty():
				var border := {"cell": cell, "directions": directions}
				borders.append(border)
				borders_by_region[id] = border
	if changed or view != world_view:
		view = world_view
		queue_redraw()

func cloud_uv(point: Vector2, cell: Vector2i) -> Vector2:
	var uv := (point - Vector2(cell) * Balance.TILE) / Balance.TILE + Vector2.ONE * 0.5
	if posmod(cell.x, 2) == 1:
		uv.x = 1.0 - uv.x
	if posmod(cell.y, 2) == 1:
		uv.y = 1.0 - uv.y
	return uv

func cloud_shape(points: PackedVector2Array, cell: Vector2i) -> void:
	var uv := PackedVector2Array()
	for point in points:
		uv.append(cloud_uv(point, cell))
	draw_polygon(points, PackedColorArray([Clouds.TINT]), uv, Clouds.CLOUDS)

func outline_aperture(points: PackedVector2Array, cell: Vector2i) -> void:
	# Only ink the exposed silhouette, not the back of the strip at the grid.
	var center := Vector2(cell) * Balance.TILE
	var half := Balance.TILE * 0.5
	for i in range(points.size()):
		var a := points[i] - center
		var b := points[(i + 1) % points.size()] - center
		var on_grid := (is_equal_approx(absf(a.x), half) and is_equal_approx(a.x, b.x)) or (is_equal_approx(absf(a.y), half) and is_equal_approx(a.y, b.y))
		if not on_grid:
			draw_line(a + center, b + center, OUTLINE, OUTLINE_WIDTH, true)

func edge_shape(center: Vector2, outward: Vector2, phase: int) -> PackedVector2Array:
	var half := Balance.TILE * 0.5
	var tangent := Vector2(-outward.y, outward.x)
	var edge := center + outward * half
	var points := PackedVector2Array([edge - tangent * half, edge + tangent * half])
	# Half-ellipses create closed, rounded cloud bubbles rather than a sine-wave
	# fade. Slightly varied heights keep the outline from looking mechanical.
	for lobe in range(LOBES - 1, -1, -1):
		var height := 10.0 + float(posmod(lobe * 7 + phase, 5))
		for step in range(LOBE_STEPS, -1, -1):
			if step == LOBE_STEPS and lobe < LOBES - 1:
				continue
			var angle := PI * float(step) / LOBE_STEPS
			var u := (1.0 - cos(angle)) * 0.5
			var t := -half + (float(lobe) + u) * Balance.TILE / LOBES
			points.append(edge + tangent * t - outward * (7.0 + sin(angle) * height))
	return points

func _draw() -> void:
	# A shallow, outlined billow reaches only into explored cells adjacent to
	# fog. Shared explored edges clear immediately when a neighbor is unlocked.
	var half := Balance.TILE * 0.5
	for id in preload("res://scripts/rendering/region_query.gd").in_view(borders_by_region, view, half):
		var border: Dictionary = borders_by_region[id]
		var cell: Vector2i = border.cell
		var center := Vector2(cell) * Balance.TILE
		if not view.grow(half).has_point(center):
			continue
		var aperture := PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half), center + Vector2(half, half), center + Vector2(-half, half)])
		for outward in border.directions:
			var shape := edge_shape(center, outward, posmod(cell.x * 17 + cell.y * 31, 19))
			cloud_shape(shape, cell)
			# Subtract each bank from the explored opening. Its final perimeter
			# closes every corner, including a tile surrounded on all four sides.
			var clipped := Geometry2D.clip_polygons(aperture, shape)
			if not clipped.is_empty():
				aperture = clipped[0]
		outline_aperture(aperture, cell)
