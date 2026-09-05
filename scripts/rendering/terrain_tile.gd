class_name VigilTerrainTile
extends Control

var region: Dictionary
var roads: Array[PackedVector2Array] = []
var scenery: Array[Dictionary] = []
var world_center := Vector2.ZERO

func configure(data: Dictionary, seed_value: int) -> void:
	roads.clear()
	scenery.clear()
	region = data
	world_center = VigilWorld.center(region.id)
	position = world_center - Vector2.ONE * Balance.TILE * 0.5
	size = Vector2.ONE * Balance.TILE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in range(4):
		var points := PackedVector2Array()
		for point in VigilWorld.spoke(region, side):
			points.append(point - world_center)
		roads.append(points)
	plan_scenery(seed_value)
	queue_redraw()

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
		for pad in VigilWorld.PADS:
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
	# All outlines first, then all fills keep the four road spokes connected.
	for road in roads:
		draw_polyline(road, VigilTerrainArt.INK, 28.0, true)
	for road in roads:
		draw_polyline(road, VigilTerrainArt.ROAD, 23.0, true)
	for pad in VigilWorld.PADS:
		VigilTerrainArt.socket(self, pad)
	for prop in scenery:
		VigilTerrainArt.scenery(self, region.get("style", "forest"), prop.pos, prop.extent)
