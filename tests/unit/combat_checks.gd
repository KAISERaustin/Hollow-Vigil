extends RefCounted

static func run(suite: SceneTree) -> void:
	test_roles_and_escapes(suite)
	test_core(suite)
	test_road_junctions(suite)

static func test_roles_and_escapes(suite: SceneTree) -> void:
	var g := VigilState.new(456)
	g.data.balance = 10000
	g.expand("-1,0")
	suite.check(g.economy.unlock("-1,0", "fast") and g.economy.unlock("-1,0", "heavy"), "Enemy roles unlock explicitly")
	var before: float = g.data.balance
	suite.check(not g.economy.unlock("-1,0", "fast") and g.data.balance == before, "Duplicate unlock is free of side effects")
	g.combat.rng.seed = 12345
	var counts := {"basic": 0, "fast": 0, "heavy": 0}
	for i in range(1000):
		var e := g.combat.spawn("-1,0")
		counts[e.kind] += 1
	suite.check(counts.basic > 470 and counts.fast > 200 and counts.heavy > 100, "Basic enemies remain abundant alongside both unlocked roles")
	g.combat.enemies.clear()
	g.data.towers.clear()
	before = g.data.balance
	suite.advance(g, 60)
	suite.check(g.data.escapes > 10 and g.data.balance == before and g.data.lifetime_earnings == 0, "Escapes are harmless and never create income")
	suite.check(g.combat.enemy_serial > 1020, "Empty battlefield continues spawning indefinitely")
	var period := g.economy.spawn_period("-1,0")
	suite.check(g.economy.buy_traffic("-1,0", 0) and g.economy.spawn_period("-1,0") < period, "Traffic upgrade increases opportunity")
	suite.check(not g.economy.buy_traffic("-1,0", 0), "Stale traffic action cannot apply twice")
	suite.check(Balance.stats("splash", 1).splash > 0 and Balance.stats("heavy", 1).damage > Balance.stats("rapid", 1).damage, "Three towers have distinct roles")
	var blast := VigilState.new(55)
	blast.data.towers.clear()
	blast.data.balance = 500
	var id := blast.economy.build("splash", "0,0", 0)
	for i in range(4):
		var target: Dictionary = suite.fixture_enemy(blast, "basic")
		target.pos = Vector2(-76 + i * 4, 0)
	blast.combat.tick(Balance.STEP)
	suite.check(blast.data.kills >= 4 and blast.data.towers[id].earnings >= 20, "Splash damages multiple nearby enemies")
	print("PASS GROUP: enemy roles, splash, and harmless escapes")

static func test_core(suite: SceneTree) -> void:
	var g := VigilState.new(4242)
	g.data.balance = 100000.0
	g.data.towers.clear()
	for direction in VigilWorld.DIRS:
		suite.check(g.expand(VigilWorld.key(direction)), "Can expand on each side of the core")
	for r in g.data.regions.values():
		r.timer = 1000.0
	var before: float = g.data.balance
	for id in g.paths:
		if not VigilWorld.has_rift(id):
			continue
		var path: Array = g.paths[id]
		suite.check(path.back() == Vector2.ZERO, "Rift %s terminates at the center" % id)
		suite.check(path.count(Vector2.ZERO) == 1, "Rift %s does not pass through the core and leave again" % id)
		for kind in Balance.ENEMIES:
			var e := g.combat.spawn(id, kind)
			e.segment = path.size() - 1
			var half_step: float = Balance.ENEMIES[kind].speed * Balance.STEP * 0.5
			e.pos = Vector2.ZERO.move_toward(path[-2], half_step)
			var escaped: float = g.data.escapes
			g.combat.tick(Balance.STEP)
			suite.check(e.dead and e.pos == Vector2.ZERO and g.data.escapes == escaped + 1, "%s from %s escapes at the core without overshooting" % [kind, id])
			suite.check(not g.combat.hit(e, 1000.0, "missing"), "Escaped enemies cannot be killed or paid out")
			g.combat.tick(Balance.STEP)
			suite.check(g.data.escapes == escaped + 1, "An enemy can only escape once")
	suite.check(g.data.balance == before and g.data.kills == 0 and g.data.lifetime_earnings == 0, "Core escapes cost nothing and award no gold or kills")
	suite.check(not g.combat.effects.is_empty() and g.combat.effects.back().kind == "escape" and g.combat.effects.back().pos == Vector2.ZERO, "Escape feedback occurs at the core")
	for pad in range(4):
		var defense := VigilState.new(19)
		defense.data.towers.clear()
		defense.data.regions["0,0"].timer = 1000.0
		var tower := defense.economy.build("rapid", "0,0", pad)
		var target: Dictionary = suite.fixture_enemy(defense)
		target.hp = Balance.stats("rapid", 1).damage
		target.pos = Vector2(-8, 0)
		defense.combat.tick(Balance.STEP)
		suite.check(tower != "" and defense.data.kills == 1 and defense.data.escapes == 0 and defense.data.towers[tower].earnings == 5, "Socket %d can intercept enemies near the core" % pad)
	print("PASS GROUP: central core, all approach directions, surrounding defenses, and exact escapes")

static func test_road_junctions(suite: SceneTree) -> void:
	for bend in [-24.0, 24.0]:
		for child_id in ["1,-1", "1,1"]:
			var g := VigilState.new(3793525839)
			g.data.towers.clear()
			g.data.regions["1,0"] = VigilWorld.make_region("1,0", "0,0", g.data.seed)
			g.data.regions["1,0"].bend = bend
			g.data.regions["1,0"].road_version = 1
			g.data.regions[child_id] = VigilWorld.make_region(child_id, "1,0", g.data.seed)
			g.refresh_paths()
			for r in g.data.regions.values():
				r.timer = 1000.0
			var junction := VigilWorld.center("1,0") + Vector2(bend, 0)
			var segment: int = g.paths[child_id].find(junction)
			suite.check(segment > 0, "Route from %s reaches the road junction with bend %s" % [child_id, bend])
			if segment <= 0:
				continue
			for kind in ["basic", "fast", "heavy"]:
				g.combat.enemies.clear()
				var enemy := g.combat.spawn(child_id, kind)
				var half_step: float = Balance.ENEMIES[kind].speed * Balance.STEP * 0.5
				var approach := -1.0 if child_id == "1,-1" else 1.0
				enemy.pos = junction + Vector2(0, approach * half_step)
				enemy.segment = segment
				g.combat.tick(Balance.STEP)
				suite.check(enemy.pos.is_equal_approx(junction + Vector2(-half_step, 0)), "%s from %s turns left immediately at Rift 1,0 with bend %s" % [kind, child_id, bend])
				var previous: Vector2 = enemy.pos
				g.combat.tick(Balance.STEP)
				suite.check(enemy.pos.is_equal_approx(previous + Vector2(-2.0 * half_step, 0)), "%s keeps moving left without pausing after the junction" % kind)
	print("PASS GROUP: immediate road turns for all enemy types")
