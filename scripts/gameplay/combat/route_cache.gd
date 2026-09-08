extends RefCounted

## One combat owns this weak interning table. Removed routes cannot retain actors
## or geometry. Hash collisions are resolved by comparing the actual waypoints.
const Geometry = preload("res://scripts/gameplay/combat/route_geometry.gd")
var routes: Dictionary = {}
var assignments := 0

func assign(enemy: Dictionary, route: Array) -> void:
	assignments += 1
	if assignments % 128 == 0: prune()
	var key := route.hash()
	var bucket: Array = routes.get(key, [])
	var geometry
	for reference in bucket:
		var candidate = reference.get_ref()
		if candidate != null and candidate.points == route:
			geometry = candidate
			break
	if geometry == null:
		geometry = Geometry.new(route)
		bucket.append(weakref(geometry))
		routes[key] = bucket
	enemy.path = geometry.points
	enemy._route_geometry = geometry
	enemy.distance_remaining = -1.0

func prune() -> void:
	for key in routes.keys():
		var live: Array = routes[key].filter(func(reference): return reference.get_ref() != null)
		if live.is_empty(): routes.erase(key)
		else: routes[key] = live
