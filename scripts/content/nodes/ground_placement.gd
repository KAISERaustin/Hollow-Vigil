extends RefCounted
## Shared, stateless placement geometry. Economy owns spending and instances.
const FOOTPRINT := 18.0
const ROAD_CLEARANCE := 14.0 + FOOTPRINT
const PORTAL_CLEARANCE := 48.0

static func campaign_bounds(mission: Dictionary) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for road in mission.routes:
		for point in road: bounds = bounds.expand(point)
	for socket in mission.sockets: bounds = bounds.expand(socket.position)
	return bounds.grow(150.0)

static func allowed(data: Dictionary, point: Vector2, authored: Array = [], bounds: Rect2 = Rect2(), ignore_id: String = "") -> bool:
	if not point.is_finite(): return false
	var location := VigilWorld.ground_location(point)
	if not data.regions.has(location.region): return false
	if bounds.has_area() and not bounds.grow(-FOOTPRINT).has_point(point): return false
	for tower in data.towers.values():
		if tower.id != ignore_id and point.distance_to(VigilWorld.pad_position(tower.region, int(tower.pad))) < FOOTPRINT * 2.0:
			return false
	if point.distance_to(Vector2.ZERO) < PORTAL_CLEARANCE: return false
	var roads: Array = authored
	if authored.is_empty():
		roads = []
		# Include adjacent tiles so footprints cannot overlap a road across a seam.
		var cell := VigilWorld.coord(location.region)
		for y in range(-1, 2):
			for x in range(-1, 2):
				var id := VigilWorld.key(cell + Vector2i(x, y))
				if not data.regions.has(id): continue
				if VigilWorld.has_rift(id, data.regions, int(data.seed)) and point.distance_to(VigilWorld.center(id)) < PORTAL_CLEARANCE: return false
				for side in range(4): roads.append(VigilWorld.spoke(data.regions[id], side))
	for road in roads:
		if road.is_empty(): continue
		if not authored.is_empty() and point.distance_to(road[0]) < PORTAL_CLEARANCE: return false
		for i in range(road.size() - 1):
			if Geometry2D.get_closest_point_to_segment(point, road[i], road[i + 1]).distance_to(point) < ROAD_CLEARANCE: return false
	return true
