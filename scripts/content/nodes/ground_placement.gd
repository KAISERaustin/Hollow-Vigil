extends RefCounted
## Shared, stateless placement geometry. Economy owns spending and instances.
# Environmental exclusion shapes. Default 36-unit squares retain the former
# 26-unit road and 48-unit portal axial clearances, with solid square corners.
const ROAD_RADIUS := 8.0
const PORTAL_RADIUS := 30.0

static func collider(kind: String) -> Resource:
	var tower := VigilContentRegistry.tower(kind)
	return tower.placement_collider() if tower != null else null

static func campaign_bounds(mission: Dictionary) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for road in mission.routes:
		for point in road: bounds = bounds.expand(point)
	for socket in mission.sockets: bounds = bounds.expand(socket.position)
	return bounds.grow(150.0)

static func allowed(data: Dictionary, point: Vector2, kind: String, authored: Array = [], bounds: Rect2 = Rect2(), ignore_id: String = "") -> bool:
	if not point.is_finite(): return false
	var candidate := collider(kind)
	if candidate == null or not candidate.valid(): return false
	var location := VigilWorld.ground_location(point)
	if not data.regions.has(location.region): return false
	if bounds.has_area() and not candidate.fits_bounds(point, bounds): return false
	for tower in data.towers.values():
		if tower.id == ignore_id: continue
		var existing := collider(tower.kind)
		if existing == null or not existing.valid(): return false
		if candidate.overlaps(point, existing, VigilWorld.pad_position(tower.region, int(tower.pad))): return false
	var portal := CircleShape2D.new()
	portal.radius = PORTAL_RADIUS
	if candidate.overlaps_shape(point, portal, Transform2D.IDENTITY): return false
	var segment := CapsuleShape2D.new()
	segment.radius = ROAD_RADIUS
	for road in authored:
		if road.is_empty(): continue
		if candidate.overlaps_shape(point, portal, Transform2D(0.0, road[0])): return false
		for i in range(road.size() - 1):
			var start: Vector2 = road[i]
			var end: Vector2 = road[i + 1]
			segment.height = start.distance_to(end) + ROAD_RADIUS * 2.0
			if candidate.overlaps_shape(point, segment, Transform2D((end - start).angle() - PI / 2.0, (start + end) * 0.5)): return false
	return true
