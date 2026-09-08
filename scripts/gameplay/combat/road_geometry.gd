extends RefCounted

## Shared spatial index for mechanics that act on existing road segments.
## Rebuilt by the route owner, never by each tower or by the renderer.
const CELL := 300.0
var segments: Array[Dictionary] = []
var buckets := {}

func rebuild(roads: Array) -> void:
	segments.clear()
	buckets.clear()
	var seen := {}
	for road in roads:
		for index in range(1, road.size()):
			var a: Vector2 = road[index - 1]
			var b: Vector2 = road[index]
			if a.is_equal_approx(b) or seen.get(a, {}).has(b) or seen.get(b, {}).has(a): continue
			if not seen.has(a): seen[a] = {}
			seen[a][b] = true
			var id := segments.size()
			segments.append({"from": a, "to": b})
			var first := Vector2i((a.min(b) / CELL).floor())
			var last := Vector2i((a.max(b) / CELL).floor())
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					var key := Vector2i(x, y)
					if not buckets.has(key): buckets[key] = []
					buckets[key].append(id)

func nearby(center: Vector2, radius: float) -> Array[Dictionary]:
	var first := Vector2i(((center - Vector2.ONE * radius) / CELL).floor())
	var last := Vector2i(((center + Vector2.ONE * radius) / CELL).floor())
	var found := {}
	var result: Array[Dictionary] = []
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			for id in buckets.get(Vector2i(x, y), []): found[id] = true
	var ordered: Array = found.keys()
	ordered.sort()
	for id in ordered:
		var segment: Dictionary = segments[id]
		var point := Geometry2D.get_closest_point_to_segment(center, segment.from, segment.to)
		if point.distance_squared_to(center) <= radius * radius: result.append(segment)
	return result
