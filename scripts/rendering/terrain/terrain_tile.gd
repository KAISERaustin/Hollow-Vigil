class_name VigilTerrainTile
extends Control

var region: Dictionary
var roads: Array[PackedVector2Array] = []
var scenery: Array[Dictionary] = []
var ground_details: Array[Dictionary] = []
var world_center := Vector2.ZERO
var pads: Array = []

func configure(data: Dictionary, seed_value: int, authored: Dictionary = {}) -> void:
	roads.clear()
	scenery.clear()
	ground_details.clear()
	region = data
	world_center = VigilWorld.center(region.id)
	position = world_center - Vector2.ONE * Balance.TILE * 0.5
	size = Vector2.ONE * Balance.TILE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pads = authored.get("pads", VigilWorld.PADS)
	for side in range(4) if authored.is_empty() else []:
		var points := PackedVector2Array()
		for point in VigilWorld.spoke(region, side):
			points.append(point - world_center)
		roads.append(points)
	for route in authored.get("roads", []):
		var points := PackedVector2Array()
		for point in route:
			points.append(point - world_center)
		roads.append(points)
	plan_scenery(seed_value)
	plan_ground_details(seed_value)
	queue_redraw()

func plan_ground_details(seed_value: int) -> void:
	# Cache an independent decoration stream; never consume gameplay randomness.
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("ground-details:" + region.id + ":" + str(seed_value)).hash())
	for attempt in range(240):
		if ground_details.size() >= 32:
			break
		var p := Vector2(rng.randf_range(-128, 128), rng.randf_range(-128, 128))
		if p.length() < 40:
			continue
		var blocked := false
		for pad in pads:
			if Rect2(pad + Vector2(-29, -64), Vector2(58, 94)).has_point(p):
				blocked = true
		for road in roads:
			for i in range(road.size() - 1):
				if Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1]).distance_to(p) < 23:
					blocked = true
		for prop in scenery:
			if prop.pos.distance_to(p) < 24:
				blocked = true
		for detail in ground_details:
			if detail.pos.distance_to(p) < 22:
				blocked = true
		if not blocked:
			ground_details.append({"pos": p, "variant": rng.randi_range(0, 5), "scale": rng.randf_range(0.8, 1.2)})

func plan_scenery(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("minimal-scenery:" + region.id + ":" + str(seed_value)).hash())
	for attempt in range(100):
		if scenery.size() >= 3:
			break
		var extent := rng.randf_range(23, 30)
		var p := Vector2(rng.randf_range(-124, 124), rng.randf_range(-124, 124))
		if p.length() < 58:
			continue
		var blocked := false
		for pad in pads:
			# Reserve the full tower silhouette above each socket, even before
			# it is built, so a prop never grows out of a roof or flame.
			if p.distance_to(pad) < 46 or Rect2(pad + Vector2(-36, -64), Vector2(72, 102)).has_point(p):
				blocked = true
		for road in roads:
			for i in range(road.size() - 1):
				if Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1]).distance_to(p) < 34:
					blocked = true
		for prop in scenery:
			if prop.pos.distance_to(p) < 60:
				blocked = true
		if not blocked:
			scenery.append({"pos": p, "extent": extent})

func _draw() -> void:
	if region.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), VigilTerrainArt.ground_color(region.get("style", "forest")))
	draw_set_transform(Vector2.ONE * Balance.TILE * 0.5)
	var style: String = region.get("style", "forest")
	for detail in ground_details:
		VigilTerrainArt.ground_detail(self, style, detail.pos, detail.variant, detail.scale)
	# All outlines first, then all fills keep the four road spokes connected.
	for road in roads:
		draw_polyline(road, VigilTerrainArt.INK, 28.0, true)
	for road in roads:
		draw_polyline(road, VigilTerrainArt.ROAD, 23.0, true)
	for road in roads:
		VigilTerrainArt.road_detail(self, road)
	for pad in pads:
		VigilTerrainArt.socket(self, pad)
	for prop in scenery:
		VigilTerrainArt.scenery(self, region.get("style", "forest"), prop.pos, prop.extent)
