extends RefCounted
## Stateless map illustration kit. Callers own chapter geometry and progression.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")

static func curve(from: Vector2, to: Vector2, departure: Vector2 = Vector2.INF, arrival: Vector2 = Vector2.INF) -> PackedVector2Array:
	var bend := (to.y - from.y) * 0.55
	if departure == Vector2.INF: departure = from + Vector2(0, bend)
	if arrival == Vector2.INF: arrival = to - Vector2(0, bend)
	var points := PackedVector2Array()
	for step in range(33):
		points.append(from.bezier_interpolate(departure, arrival, to, step / 32.0))
	return points

static func trail(canvas: CanvasItem, points: PackedVector2Array, completed: bool) -> void:
	canvas.draw_polyline(points, Art.INK, 6 + UI.OUTLINE * 2, true)
	canvas.draw_polyline(points, Art.GOLD if completed else Art.ROAD, 6, true)

static func between_markers(from: Vector2, to: Vector2) -> PackedVector2Array:
	# Leave vertically before bending so long labels remain clear on wide screens.
	var points := PackedVector2Array([from])
	points.append_array(curve(from + Vector2(0, 34), to - Vector2(0, 34)))
	points.append(to)
	return points

static func scenery(canvas: CanvasItem, style: String, bounds: Rect2, reserved: Array[Rect2], roads: Array[PackedVector2Array], seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed: Array[Vector2] = []
	for attempt in range(160):
		if placed.size() >= 14: break
		var at := Vector2(rng.randf_range(bounds.position.x + 20, bounds.end.x - 20), rng.randf_range(bounds.position.y + 22, bounds.end.y - 22))
		var blocked := false
		for rect in reserved:
			if rect.grow(18).has_point(at): blocked = true
		for road in roads:
			for i in range(1, road.size()):
				if Geometry2D.get_closest_point_to_segment(at, road[i-1], road[i]).distance_to(at) < 24: blocked = true
		for previous in placed:
			if previous.distance_to(at) < 42: blocked = true
		if blocked: continue
		placed.append(at)
		if placed.size() % 3 == 0:
			Art.ground_detail(canvas, style, at, attempt % 6, 1.0)
		else:
			Art.scenery(canvas, style, at, rng.randf_range(23, 34))
