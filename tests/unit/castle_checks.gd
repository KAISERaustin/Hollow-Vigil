extends RefCounted

const Areas = preload("res://scripts/world/hidden_areas.gd")
const Plan = preload("res://scripts/world/castle_plan.gd")
const Bosses = preload("res://scripts/gameplay/encounters/bosses.gd")

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
			suite.check(VigilWorld.is_ruin(VigilWorld.key(cell), 879), "Every castle footprint cell is a claimable ruin")
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
	var claimed := fixture()
	var claim_gate := Areas.gate(Vector2i.ZERO, 879)
	var before_gold: float = claimed.data.balance
	suite.check(claimed.expand(claim_gate.id), "Connected castle gate can be purchased")
	suite.check(claimed.data.balance < before_gold and not claimed.expand(claim_gate.id), "Ruin charges once and rejects repeat purchase")
	suite.check(claimed.data.regions[claim_gate.id].style == "castle_ruin", "Claimed castle becomes a dungeon tile")
	var towers: Array[String] = []
	for pad in range(4):
		towers.append(claimed.economy.build("heavy", claim_gate.id, pad))
		suite.check(towers[-1] != "", "Every ruin tower socket supports building")
	var seen := {}
	for i in range(20):
		suite.check(claimed.combat.spawn(claim_gate.id).kind == "shade", "Unattuned ruin spawns only its starting enemy")
	var saved_gold: float = claimed.data.balance
	claimed.data.balance = 549.0
	suite.check(not claimed.economy.unlock(claim_gate.id, "sentinel") and claimed.data.balance == 549.0, "Sentinel purchase rejects insufficient gold")
	claimed.data.balance = saved_gold
	suite.check(claimed.economy.unlock(claim_gate.id, "sentinel") and claimed.data.balance == saved_gold - 550.0, "Sentinel purchase costs 550 gold")
	suite.check(not claimed.economy.unlock(claim_gate.id, "sentinel") and claimed.data.balance == saved_gold - 550.0, "Duplicate Sentinel purchase cannot charge")
	suite.check(fixture().data.regions.values().all(func(r): return r.unlocks.is_empty()), "Purchases do not alter another game")
	suite.check(not claimed.economy.unlock(claim_gate.neighbor, "sentinel"), "Ordinary rifts cannot buy dungeon enemies")
	for i in range(80):
		var mob := claimed.combat.spawn(claim_gate.id)
		seen[mob.kind] = true
		suite.check(mob.kind in Balance.DUNGEON_KINDS and mob.pos == VigilWorld.center(claim_gate.id), "Dungeon mobs emerge only at central ruin portal")
		suite.check(mob.path[-1] == VigilWorld.CORE_POSITION, "Dungeon route reaches the core")
	suite.check(seen.size() == 2, "Both exclusive dungeon mobs spawn after attunement")
	for kind in ["sepulcher"]:
		var cost: float = Balance.portal_unlock_costs("castle_ruin")[kind]
		var gold: float = claimed.data.balance
		claimed.data.balance = cost - 1.0
		suite.check(not claimed.economy.unlock(claim_gate.id, kind) and claimed.data.balance == cost - 1.0, "Elite attunement rejects insufficient gold")
		claimed.data.balance = gold
		suite.check(not claimed.economy.unlock(claim_gate.neighbor, kind), "Elite attunement is exclusive to ruins")
		suite.check(claimed.economy.unlock(claim_gate.id, kind) and claimed.data.balance == gold - cost, "Elite attunement charges its catalog cost")
		suite.check(not claimed.economy.unlock(claim_gate.id, kind) and claimed.data.balance == gold - cost, "Elite attunement charges only once")
	seen.clear()
	for i in range(120):
		var mob := claimed.combat.spawn(claim_gate.id)
		seen[mob.kind] = true
		claimed.combat.hit(mob, 10000, towers[0])
	for kind in Balance.DUNGEON_KINDS:
		suite.check(seen.has(kind), "Every attuned dungeon type naturally spawns: " + kind)
	for kind in Balance.DUNGEON_KINDS:
		suite.check(claimed.combat.spawn(claim_gate.neighbor, kind).is_empty(), "Normal rifts reject dungeon mobs")
		var mob := claimed.combat.spawn(claim_gate.id, kind)
		var stored: float = claimed.data.towers[towers[0]].earnings
		suite.check(claimed.combat.hit(mob, 10000, towers[0]), "Dungeon mobs can be defeated")
		suite.check(claimed.data.towers[towers[0]].earnings == stored + Balance.ENEMIES[kind].payout, "Dungeon bounty is credited exactly")
		suite.check(not claimed.combat.hit(mob, 10000, towers[0]), "Dungeon bounty cannot be collected twice")
	suite.check(claimed.combat.spawn(claim_gate.id, "basic").is_empty() and not claimed.economy.unlock(claim_gate.id, "fast"), "Dungeon portals reject ordinary mobs and attunements")
	var remaining := Areas.cluster(Vector2i.ZERO, 879).duplicate()
	remaining.erase(VigilWorld.coord(claim_gate.id))
	for cell in remaining:
		suite.check(Areas.reserved(cell, 879, claimed.data.regions), "Buying the portal preserves every unclaimed dungeon square")
	while not remaining.is_empty():
		var bought := false
		for cell in remaining.duplicate():
			var id := VigilWorld.key(cell)
			if not VigilWorld.frontier(claimed.data.regions).has(id):
				continue
			suite.check(claimed.expand(id), "Remaining dungeon territory can be purchased individually")
			suite.check(not VigilWorld.has_rift(id, claimed.data.regions, 879), "Only the fixed gate tile has a dungeon portal")
			suite.check(claimed.combat.spawn(id).is_empty(), "Open dungeon territory never spawns enemies")
			suite.check(not claimed.economy.buy_traffic(id), "Open dungeon territory rejects portal upgrades")
			suite.check(claimed.paths[id][-1] == VigilWorld.CORE_POSITION, "Open dungeon territory keeps a connected path")
			remaining.erase(cell)
			bought = true
		if not bought:
			suite.check(false, "Every remaining ruin is reachable")
			break
	claimed.save_path = "user://claimed-castle.save"
	suite.clean_test_save(claimed.save_path)
	suite.check(claimed.save(1000), "Purchased castle saves during existing boss emergence")
	var reloaded := VigilState.new()
	reloaded.save_path = claimed.save_path
	suite.check(reloaded.load_save(1000), "Purchased castle restores")
	suite.check(reloaded.data.regions[claim_gate.id].unlocks.has("sentinel"), "Dungeon attunement survives save and reload")
	for kind in ["sepulcher"]:
		suite.check(reloaded.data.regions[claim_gate.id].unlocks.has(kind), "Elite attunement survives save and reload")
	suite.check(reloaded.data.regions.has(claim_gate.id) and reloaded.data.towers.size() == claimed.data.towers.size(), "Ruin and towers survive reload")
	suite.check(reloaded.combat.enemies.filter(func(e): return e.get("boss", false) and e.source == claim_gate.id).size() == 1, "Purchasing and reloading never duplicate existing castle boss")
	var portals := 0
	for cell in Areas.cluster(Vector2i.ZERO, 879):
		var id := VigilWorld.key(cell)
		suite.check(reloaded.data.regions.has(id), "All purchased dungeon territories survive reload")
		if VigilWorld.has_rift(id, reloaded.data.regions, 879):
			portals += 1
	suite.check(portals == 1, "Reload preserves exactly one dungeon portal")
	suite.clean_test_save(claimed.save_path)
	print("PASS GROUP: castle outlines, seed architecture, reservations, reachable gates, physical emergence and saves")
