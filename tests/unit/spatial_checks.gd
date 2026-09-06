extends RefCounted

const Index = preload("res://scripts/model/enemy_index.gd")
const Regions = preload("res://scripts/rendering/region_query.gd")

static func run(suite: SceneTree) -> void:
	test_queries(suite)
	test_combat(suite)
	test_regions(suite)
	test_towers(suite)
	test_terrain(suite)

static func ids(enemies: Array) -> Array:
	return enemies.map(func(e): return e.id)

static func test_queries(suite: SceneTree) -> void:
	var index := Index.new()
	var enemies: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 93012
	for i in range(2000):
		enemies.append({"id": i, "pos": Vector2(rng.randf_range(-5000, 5000), rng.randf_range(-5000, 5000)), "dead": i % 13 == 0})
	# Exact positive/negative bucket boundaries and the inclusive range edge.
	for pos in [Vector2(-128, 0), Vector2(128, 0), Vector2(0, 128), Vector2(0, -128), Vector2(128.01, 0)]:
		enemies.append({"id": enemies.size(), "pos": pos, "dead": false})
	index.rebuild(enemies)
	for query in range(50):
		var center := Vector2.ZERO if query == 0 else Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500))
		var radius := 128.0 if query == 0 else rng.randf_range(1, 400)
		var expected := enemies.filter(func(e): return not e.dead and center.distance_squared_to(e.pos) <= radius * radius)
		suite.check(ids(index.query_radius(center, radius)) == ids(expected), "Spatial radius matches full scan and order, query %d" % query)
	index.query_radius(Vector2.ZERO, 128)
	suite.check(index.candidates_checked < 100, "Local query avoids inspecting thousands of distant enemies")
	var moved := enemies[-1]
	moved.pos = Vector2(-129, -1)
	index.moved(moved)
	suite.check(ids(index.query_radius(moved.pos, 0)) == [moved.id], "Movement across a negative bucket boundary is immediately searchable")
	moved.dead = true
	suite.check(index.query_radius(moved.pos, 0).is_empty(), "Synchronous deaths are excluded without rebuilding")
	var rect := Rect2(-256, -256, 512, 512)
	var expected := enemies.filter(func(e): return not e.dead and rect.has_point(e.pos))
	suite.check(ids(index.query_rect(rect)) == ids(expected), "Viewport query preserves visible enemy draw order")
	# A repeatable diagnostic; correctness does not depend on machine timing.
	var started := Time.get_ticks_usec()
	for i in range(200):
		index.query_radius(Vector2.ZERO, 128)
	var indexed_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for i in range(200):
		enemies.filter(func(e): return not e.dead and e.pos.length_squared() <= 128.0 * 128.0)
	print("SPATIAL_BENCH: 200 queries / %d enemies: indexed=%dus full_scan=%dus candidates=%d" % [enemies.size(), indexed_us, Time.get_ticks_usec() - started, index.candidates_checked])

static func test_combat(suite: SceneTree) -> void:
	var g: VigilState = suite.legacy_core_fixture(310)
	g.data.balance = 1e9
	var tid := g.economy.build("splash", "0,0", 0)
	var a: Dictionary = suite.fixture_enemy(g, "heavy")
	var b: Dictionary = suite.fixture_enemy(g, "heavy")
	var far: Dictionary = suite.fixture_enemy(g, "heavy")
	a.pos = Vector2(129, 0)
	b.pos = Vector2(145, 0)
	far.pos = Vector2(2000, 0)
	for e in [a, b, far]:
		e.hp = 10000.0
		e.max_hp = e.hp
		e.path = [Vector2.ZERO, Vector2(3000, 0)]
		e.segment = 1
	g.combat.rebuild_enemy_index()
	g.combat.ticking = true
	g.combat.push_back(a, 20)
	suite.check(ids(g.combat.nearby_enemies(Vector2(109, 0), 1)) == [a.id], "Knockback relocates the index before the next attack")
	var shot := {"fx": {"pos": Vector2(128, 0), "flight": 0.0}, "radius": 19.0, "tower_id": tid, "target_id": a.id, "damage": 10.0}
	g.combat.resolve_shot(shot, a)
	suite.check(a.hp == 9990 and b.hp == 9990 and far.hp == 10000, "Splash hits the inclusive range edge across cells and excludes distant enemies")
	g.combat.burning_ground = [
		{"pos": a.pos, "radius": 50.0, "tower_id": tid, "until": 100.0, "damage": 10.0},
		{"pos": b.pos, "radius": 50.0, "tower_id": tid, "until": 100.0, "damage": 99.0}]
	g.combat.advance_fire(1)
	suite.check(a.hp == 9980 and b.hp == 9980 and far.hp == 10000, "Overlapping fire preserves first-patch damage and deduplicates each owner")
	var arrow := {"fx": {"from": Vector2(90, 0), "pos": Vector2(160, 0), "flight": 1.0, "life": 1.0}, "elapsed": 0.0, "damage": 5.0, "tower_id": tid}
	var flying: Array[Dictionary] = []
	g.combat.advance_arrow(arrow, 1, flying)
	suite.check(a.hp == 9975 and b.hp == 9980 and flying.is_empty(), "Swept arrow query finds the nearest hit across bucket boundaries")
	g.combat.ticking = false
	# Direct helper calls may follow fixture or editor position changes.
	b.pos = Vector2(-500, -500)
	suite.check(ids(g.combat.nearby_enemies(b.pos, 1)) == [b.id], "Standalone combat calls refresh positions")
	a.dead = true
	g.combat.recycle_dead_enemies()
	var reused := g.combat.spawn("-1,0", "basic")
	suite.check(ids(g.combat.visible_enemies(Rect2(reused.pos - Vector2.ONE, Vector2.ONE * 2))).has(reused.id), "Pooled spawn invalidates the rendering index")

static func test_regions(suite: SceneTree) -> void:
	var regions := {}
	for x in range(-50, 51):
		for y in range(-50, 51):
			regions[VigilWorld.key(Vector2i(x, y))] = true
	for zoom in [0.42, 1.0, 1.65]:
		for camera in [Vector2.ZERO, Vector2(-155, -301), Vector2(15000, 15000)]:
			var view := Rect2(camera - Vector2(200, 350) / zoom, Vector2(400, 700) / zoom)
			var actual := Regions.in_view(regions, view, 150)
			var expected: Array[String] = []
			for id in regions:
				var p := VigilWorld.center(id)
				if p.x >= view.position.x - 150 and p.y >= view.position.y - 150 and p.x <= view.end.x + 150 and p.y <= view.end.y + 150:
					expected.append(id)
			suite.check(actual == expected, "Visible region lookup matches full-world scan at zoom %s camera %s" % [zoom, camera])
	var local := Regions.in_view(regions, Rect2(-200, -350, 400, 700), 150)
	suite.check(local.size() == 9, "A 10201-region world returns only nine nearby sections")

static func test_towers(suite: SceneTree) -> void:
	var g: VigilState = suite.legacy_core_fixture(999)
	g.data.balance = 1e9
	var first := g.economy.build("rapid", "0,0", 0)
	var second := g.economy.build("heavy", "0,0", 1)
	var regions: Array[String] = ["0,0"]
	suite.check(ids(g.economy.towers_in_regions(regions)) == [first, second], "Visible towers preserve build order")
	suite.check(g.economy.relocate(first, "0,0", 2), "Tower relocation succeeds with the spatial lookup")
	suite.check(g.economy.tower_at("0,0", 0) == "" and g.economy.tower_at("0,0", 2) == first, "Relocation invalidates occupied-pad lookup even with unchanged tower count")
	g.economy.sell(second)
	var replacement := g.economy.build("electric", "0,0", 1)
	suite.check(g.economy.tower_at("0,0", 1) == replacement, "Sell and rebuild cannot leave a stale tower index")
	var loaded := VigilEconomy.new(g.data.duplicate(true))
	suite.check(ids(loaded.towers_in_regions(regions)) == [first, replacement], "A newly loaded economy reconstructs its tower lookup")

static func test_terrain(suite: SceneTree) -> void:
	var g := VigilState.new(125)
	# Isolated region dictionaries exercise lazy drawing without expensive routes.
	g.data.regions["20,0"] = VigilWorld.make_region("20,0", "0,0", 125)
	g.terrain_revision += 1
	var layer := VigilTerrainLayer.new()
	layer.synchronize(g, Vector2.ZERO, 1.0, Vector2(200, 200))
	suite.check(layer.chunks.has("0,0") and not layer.chunks.has("20,0"), "Offscreen terrain is not created until first visible")
	layer.synchronize(g, Vector2(6000, 0), 1.0, Vector2(200, 200))
	suite.check(layer.chunks["20,0"].visible and not layer.chunks["0,0"].visible, "Camera travel shows new chunks and hides old chunks")
	layer.synchronize(g, Vector2.ZERO, 0.42, Vector2(200, 200))
	suite.check(layer.chunks["0,0"].visible and not layer.chunks["20,0"].visible, "Returning at a different zoom reuses cached terrain")
	g.data.regions["0,0"].style = "ashen_forge"
	g.terrain_revision += 1
	layer.synchronize(g, Vector2.ZERO, 1.65, Vector2(200, 200))
	suite.check(layer.chunks["0,0"].region.style == "ashen_forge", "Terrain revision refreshes visible cached appearance")
	layer.free()
