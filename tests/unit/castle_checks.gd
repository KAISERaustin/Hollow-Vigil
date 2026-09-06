extends RefCounted

const Areas = preload("res://scripts/world/hidden_areas.gd")
const Plan = preload("res://scripts/world/castle_plan.gd")
const Bosses = preload("res://scripts/model/bosses.gd")

static func reach(game: VigilState, target: String) -> void:
	var queue: Array[String] = ["0,0"]
	var parents := {"0,0": ""}
	var head := 0
	while head < queue.size() and not parents.has(target):
		var id := queue[head]
		head += 1
		for direction in VigilWorld.DIRS:
			var cell: Vector2i = VigilWorld.coord(id) + direction
			var next := VigilWorld.key(cell)
			if parents.has(next) or maxi(absi(cell.x), absi(cell.y)) > 35 or Areas.reserved(cell, int(game.data.seed), game.data.regions):
				continue
			parents[next] = id
			queue.append(next)
	assert(parents.has(target), "Castle approach must be reachable around reserved footprints")
	var route: Array[String] = []
	var cursor := target
	while cursor != "0,0":
		route.push_front(cursor)
		cursor = parents[cursor]
	for id in route:
		if not game.data.regions.has(id):
			assert(game.expand(id))

static func fixture(sector: Vector2i = Vector2i.ZERO, seed_value: int = 879) -> VigilState:
	var game := VigilState.new(seed_value)
	game.data.balance = 1.0e12
	reach(game, Areas.gate(sector, seed_value).neighbor)
	return game

static func run(suite: SceneTree) -> void:
	var variants := {}
	var orientations := {}
	var movement_sectors := {}
	for seed_value in [1, 879, 45678]:
		for y in range(-2,3):
			for x in range(-2,3):
				var sector := Vector2i(x,y)
				var plan := Plan.build(sector, seed_value)
				variants[plan.variant] = true
				orientations[plan.gate.side] = true
				if seed_value == 879 and not movement_sectors.has(plan.gate.side):
					movement_sectors[plan.gate.side] = sector
				suite.check(plan == Plan.build(sector, seed_value), "Complete castle architecture and damage are seed-stable")
				suite.check(plan.cells.has(VigilWorld.coord(plan.gate.id)) and not plan.cells.has(VigilWorld.coord(plan.gate.neighbor)), "Encounter gate belongs to one boundary tile and faces outside")
				var vertices := {}
				for edge in plan.edges:
					for p in [edge.a, edge.b]:
						vertices[p] = vertices.get(p, 0) + 1
				for count in vertices.values():
					suite.check(count == 2, "Exterior outline closes at straight, outer and inward corners")
				for wall in plan.walls:
					if wall.outer:
						continue
					var outward := Vector2(VigilWorld.DIRS[plan.gate.side])
					for i in range(8):
						var p: Vector2 = plan.gate_point - outward * i * 10.0
						suite.check(Geometry2D.get_closest_point_to_segment(p, wall.a, wall.b).distance_to(p) > 24.0, "Interior walls never obstruct the boss entrance")
	suite.check(variants.size() == 4 and orientations.size() == 4, "Distinct room plans and every gate orientation are represented")
	for sector in movement_sectors.values():
		var game := fixture(sector)
		var gate := Areas.gate(sector, 879)
		var enemies := game.combat.enemies.filter(func(e): return e.get("boss", false) and e.source == gate.id)
		suite.check(enemies.size() == 1, "Buying the reachable approach awakens exactly one castle boss")
		if enemies.size() != 1:
			continue
		var e: Dictionary = enemies[0]
		var initial := Areas.emergence(gate, game.data.regions)
		suite.check(e.path == initial and e.pos == initial[0], "Boss spawns just inside the gate on its authored threshold")
		for cell in Areas.cluster(sector, 879):
			suite.check(not game.expand(VigilWorld.key(cell)) and not game.data.regions.has(VigilWorld.key(cell)), "Castle remains decorative and cannot become a portal or tower tile")
		for r in game.data.regions.values():
			r.timer = 9.0
		game.combat.tick(0.5)
		game.save_path = "user://castle-emergence.save"
		suite.clean_test_save(game.save_path)
		suite.check(game.save(1000), "Mid-threshold encounter saves with exact validated path")
		var restored := VigilState.new()
		restored.save_path = game.save_path
		suite.check(restored.load_save(1000), "Castle encounter reloads during emergence")
		var loaded := restored.combat.enemies.filter(func(v): return v.get("boss", false) and v.source == gate.id)
		suite.check(loaded.size() == 1 and loaded[0].pos.is_equal_approx(e.pos) and loaded[0].segment == e.segment, "Reload preserves exact boss progress without teleporting or duplicating")
		var bad := game.snapshot(1000)
		bad.castles[gate.id].boss.path[0][0] += 20.0
		suite.check(not game.storage.valid_data(bad), "Off-threshold castle save is rejected")
		var crossed := false
		var outward := Vector2(VigilWorld.DIRS[gate.side])
		var edge := VigilWorld.center(gate.id) + outward * 150.0
		for i in range(220):
			var before: Vector2 = e.pos
			game.combat.tick(0.05)
			suite.check(e.pos.distance_to(before) <= Bosses.speed(e, game.combat.simulation_time) * 0.05 + 0.01, "Boss walks every threshold and route step within its speed budget")
			if (e.pos - edge).dot(outward) >= 0:
				crossed = true
		suite.check(crossed and e.previous != gate.id and not e.dead, "Boss crosses gate and joins ordinary patrol routing")
		var stable := Plan.build(sector, 879)
		for cell in Areas.cluster(sector,879):
			for direction in VigilWorld.DIRS:
				var next := VigilWorld.key(cell + direction)
				if not Areas.reserved(cell + direction, 879, game.data.regions):
					reach(game, next)
		suite.check(stable == Plan.build(sector, 879) and not Areas.preserved(sector,879,game.data.regions), "Expansion surrounds the entire castle without replacing or rerolling it")
		Bosses.discover_castles(game.combat)
		suite.check(game.combat.enemies.filter(func(v): return v.get("boss",false) and v.source == gate.id).size() == 1, "Repeated discovery cannot duplicate active encounter")
		e.wards = 0
		e.shield = 0
		var tower := game.economy.build("heavy", "0,0", 0)
		game.combat.hit(e, 1.0e6, tower, "doomstone")
		game.combat.recycle_dead_enemies()
		suite.check(game.save(1001) and restored.load_save(1001), "Defeated castle record persists")
		suite.check(restored.combat.enemies.filter(func(v): return v.get("boss",false) and v.source == gate.id).is_empty(), "Defeated castle cannot respawn on reload")
		suite.clean_test_save(game.save_path)
	print("PASS GROUP: castle outlines, seed architecture, reservations, reachable gates, physical emergence and saves")
