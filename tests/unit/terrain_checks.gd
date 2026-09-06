extends RefCounted

static func run(suite: SceneTree) -> void:
	preload("res://tests/unit/terrain_cluster_checks.gd").run(suite)
	var g := VigilState.new(879)
	var before := VigilWorld.spoke(g.data.regions["0,0"], 2)
	g.data.balance = 1e12
	g.expand("1,0")
	g.expand("0,1")
	g.expand("1,1")
	g.data.regions["1,0"].style = "ashen_forge"
	g.data.regions["0,1"].style = "drowned_crypt"
	g.data.regions["1,1"].style = "bloodmoon_sanctuary"
	g.refresh_paths()
	suite.check(before == VigilWorld.spoke(g.data.regions["0,0"], 2), "Buying neighbors never moves an existing curved road")
	var revision: int = g.terrain_revision
	var regions: Dictionary = g.data.regions.duplicate(true)
	suite.check(not g.expand("99,99") and g.data.regions == regions and revision == g.terrain_revision, "Invalid expansion cannot change terrain")
	var shapes := {}
	for n in range(48):
		var id := "%d,%d" % [n % 8 - 4, n / 8 - 3]
		var region := VigilWorld.make_region(id, "", 123 + n)
		var center := VigilWorld.center(id)
		for side in range(4):
			var road := VigilWorld.spoke(region, side)
			var neighbor_id := VigilWorld.key(VigilWorld.coord(id) + VigilWorld.DIRS[side])
			var neighbor := VigilWorld.make_region(neighbor_id, id, 123 + n)
			suite.check(road[0] == VigilWorld.spoke(neighbor, (side + 2) % 4)[0], "Curve mouths join exactly at shared tile edge")
			suite.check(road[-1] == center, "Every curved spoke reaches its own portal center")
			var clearance := true
			var bounded := true
			var length := 0.0
			for i in range(road.size() - 1):
				length += road[i].distance_to(road[i + 1])
				var local: Vector2 = road[i] - center
				bounded = bounded and absf(local.x) <= 150.0 and absf(local.y) <= 150.0
				for pad in VigilWorld.PADS:
					if Geometry2D.get_closest_point_to_segment(center + pad, road[i], road[i + 1]).distance_to(center + pad) < 39.0:
						clearance = false
			suite.check(clearance and bounded, "Curves keep roads and their edges clear of tower sockets")
			suite.check(length > 155 and length < 190, "Winding paths add controlled travel distance")
			shapes[str(road[12] - center)] = true
	suite.check(shapes.size() > 15, "Different territory IDs create varied curve silhouettes")
	# Live movement is measured against the drawn polyline, not an approximation.
	for r in g.data.regions.values():
		r.timer = 1000.0
	for id in ["1,0", "0,1", "1,1"]:
		var enemy := g.combat.spawn(id, "fast")
		var on_road := true
		for tick in range(100):
			g.combat.tick(Balance.STEP)
			if enemy.dead:
				break
			var route: Array = enemy.path
			var distance := INF
			for i in range(route.size() - 1):
				distance = minf(distance, Geometry2D.get_closest_point_to_segment(enemy.pos, route[i], route[i + 1]).distance_to(enemy.pos))
			on_road = on_road and distance < 0.01
		suite.check(on_road, "Enemies stay on the same curved road geometry used for drawing")
	g.save_path = "user://terrain-test.save"
	for r in g.data.regions.values():
		r.timer = 0.25
	suite.clean_test_save(g.save_path)
	var routes := g.paths.duplicate(true)
	suite.check(g.save(1000), "Curved roads and themed territories save")
	var loaded := VigilState.new()
	loaded.save_path = g.save_path
	suite.check(loaded.load_save(1000) and routes == loaded.paths, "Saved curves reproduce exactly")
	for region in g.data.regions.values():
		region.erase("road_version")
	suite.check(g.save(1000) and loaded.load_save(1000) and loaded.paths == routes, "Pre-redesign saves migrate deterministically without losing progress")
	loaded.data.regions["0,0"].road_version = 3
	suite.check(not loaded.storage.valid_data(loaded.data), "Unsupported road versions are rejected")
	suite.clean_test_save(g.save_path)
	print("PASS GROUP: curved road clearance, movement, and save migration")
