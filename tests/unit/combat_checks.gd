extends RefCounted

static func run(suite: SceneTree) -> void:
	test_roles_and_escapes(suite)
	test_core(suite)
	test_road_junctions(suite)
	test_targeting(suite)
	test_target_lock(suite)
	test_equal_hp_focus(suite)

static func test_equal_hp_focus(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		var g: VigilState = suite.legacy_core_fixture(855)
		g.data.balance = 10000.0
		var id := g.economy.build(kind, "0,0", 0)
		var tower: Dictionary = g.data.towers[id]
		tower.target_mode = "most_hp"
		var enemies: Array[Dictionary] = []
		for i in range(3):
			var enemy: Dictionary = suite.fixture_enemy(g, "heavy")
			enemy.pos = Vector2(-50, 0)
			enemy.path = [enemy.pos, Vector2.ZERO]
			enemy.segment = 1
			enemy.hp = 100000.0
			enemy.stun_until = 1000.0
			enemies.append(enemy)
		for region in g.data.regions.values():
			region.timer = 1000.0
		for index in range(enemies.size()):
			var expected: Dictionary = enemies[index]
			for attack in range(4):
				tower.cooldown = 0.0
				g.combat.effects.clear()
				g.combat.tick(Balance.STEP)
				var shots: Array = g.combat.effects.filter(func(fx): return fx.kind == "shot")
				suite.check(not shots.is_empty() and shots[0].get("target_id", -1) == expected.id,
					"%s keeps equal-HP enemy %d as primary target on attack %d" % [kind, index, attack])
				# Resolve actual projectile impacts before the next attack. Extra
				# damage makes the locked enemy less healthy even for area attacks.
				g.combat.advance_shots(1.0)
				g.combat.hit(expected, 100.0, id)
			g.combat.hit(expected, expected.hp + 1.0, id)
			suite.check(expected.dead, "%s finishes the focused enemy before selecting the next" % kind)

static func test_targeting(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		for mode in Balance.TARGET_MODES:
			var g: VigilState = suite.legacy_core_fixture(852)
			g.data.balance = 10000.0
			var id := g.economy.build(kind, "0,0", 0)
			suite.check(g.data.towers[id].target_mode == "first", "New towers default to First")
			g.data.towers[id].target_mode = mode
			# Oldest is Last, newest is First; highest current HP is in between.
			for i in range(3):
				var e: Dictionary = suite.fixture_enemy(g, "heavy")
				e.pos = Vector2(-100 + i * 35, 0)
				e.path = [e.pos, Vector2.ZERO]
				e.segment = 1
				e.hp = 10000.0 if i == 1 else 5000.0
			for region in g.data.regions.values():
				region.timer = 1000.0
			var expected: int = g.combat.enemies[{"first": 2, "last": 0, "most_hp": 1}[mode]].id
			g.combat.tick(Balance.STEP)
			suite.check(g.combat.effects.filter(func(fx): return fx.kind == "shot")[0].target_id == expected, "%s obeys %s targeting during combat" % [kind, mode])
	var g: VigilState = suite.legacy_core_fixture(853)
	var a := {"id": 1, "pos": Vector2(10, 0), "hp": 50.0, "dead": false, "distance_remaining": 100.0}
	var b := {"id": 2, "pos": Vector2(20, 0), "hp": 50.0, "dead": false, "distance_remaining": 50.0}
	suite.check(g.combat.select_target([a, b], Vector2.ZERO, 100, "first").id == 2, "First uses remaining road distance rather than straight-line distance")
	suite.check(g.combat.select_target([a, b], Vector2.ZERO, 100, "most_hp").id == 2, "Equal HP prefers the enemy closest along its route")
	a.distance_remaining = 50.0
	for mode in Balance.TARGET_MODES:
		suite.check(g.combat.select_target([b, a], Vector2.ZERO, 100, mode).id == 1, "Exact ties use stable spawn ID for " + mode)
	a.dead = true
	suite.check(g.combat.select_target([a, b], Vector2.ZERO, 100, "last").id == 2, "Dead enemies are excluded")
	suite.check(g.combat.select_target([a, b], Vector2.ZERO, 15, "most_hp").is_empty(), "Out-of-range enemies are excluded")
	var route := {"path": [Vector2(10, 0), Vector2(10, 20), Vector2.ZERO], "segment": 1, "pos": Vector2(10, 5)}
	suite.check(is_equal_approx(g.combat.distance_remaining(route), 15.0 + sqrt(500.0)), "Remaining distance includes every road segment")
	g.data.balance = 10000.0
	var first := g.economy.build("rapid", "0,0", 0)
	var second := g.economy.build("heavy", "0,0", 1)
	g.data.towers[first].target_mode = "last"
	g.save_path = "user://targeting-test.save"
	suite.clean_test_save(g.save_path)
	suite.check(g.save(1000.0), "Target modes can be saved")
	var loaded := VigilState.new(1)
	loaded.save_path = g.save_path
	suite.check(loaded.load_save(1000.0) and loaded.data.towers[first].target_mode == "last" and loaded.data.towers[second].target_mode == "first", "Target mode persists independently for every tower")
	var legacy := g.snapshot(1000.0)
	legacy.towers[first].erase("target_mode")
	suite.clean_test_save(g.save_path)
	suite.check(g.storage.write(g.save_path, legacy) and loaded.load_save(1000.0) and loaded.data.towers[first].target_mode == "first", "Old saves default to First")
	legacy.towers[first].target_mode = "invalid"
	suite.check(not g.storage.valid_data(legacy), "Invalid targeting modes are rejected")
	suite.clean_test_save(g.save_path)

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
	suite.check(g.combat.enemy_serial >= 1000 + int(floor(60.0 / Balance.traffic_period(0))), "Empty battlefield continues spawning indefinitely")
	var period := g.economy.spawn_period("-1,0")
	suite.check(g.economy.buy_traffic("-1,0", 0) and g.economy.spawn_period("-1,0") < period, "Traffic upgrade increases opportunity")
	suite.check(not g.economy.buy_traffic("-1,0", 0), "Stale traffic action cannot apply twice")
	suite.check(Balance.stats("splash", 1).splash > 0 and Balance.stats("heavy", 1).damage > Balance.stats("rapid", 1).damage, "Three towers have distinct roles")
	var blast: VigilState = suite.legacy_core_fixture(55)
	blast.data.towers.clear()
	blast.data.balance = 500
	var id := blast.economy.build("splash", "0,0", 0)
	for i in range(4):
		var target: Dictionary = suite.fixture_enemy(blast, "basic")
		target.pos = Vector2(-76 + i * 4, 0)
		target.hp = Balance.stats("splash", 1).damage # Isolate lethal splash behavior from enemy balance.
	blast.combat.tick(Balance.STEP)
	suite.advance(blast, 0.35)
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
		for kind in (Balance.DUNGEON_KINDS if g.data.regions[id].style == "castle_ruin" else Balance.NORMAL_KINDS):
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
		var defense: VigilState = suite.legacy_core_fixture(19)
		defense.data.towers.clear()
		defense.data.regions["0,0"].timer = 1000.0
		var tower := defense.economy.build("rapid", "0,0", pad)
		var target: Dictionary = suite.fixture_enemy(defense)
		target.hp = Balance.stats("rapid", 1).damage
		target.pos = Vector2(-15, 0)
		defense.combat.tick(Balance.STEP)
		suite.advance(defense, 0.25)
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
			for kind in Balance.NORMAL_KINDS:
				g.combat.enemies.clear()
				var enemy := g.combat.spawn(child_id, kind)
				enemy.rift_style = "forest" # Isolate exact road-junction movement.
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

static func test_target_lock(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		for mode in Balance.TARGET_MODES:
			var g: VigilState = suite.legacy_core_fixture(854)
			g.data.balance = 10000.0
			var id := g.economy.build(kind, "0,0", 0)
			var tower: Dictionary = g.data.towers[id]
			tower.target_mode = mode
			var a: Dictionary = suite.fixture_enemy(g, "heavy")
			var b: Dictionary = suite.fixture_enemy(g, "heavy")
			for enemy in [a, b]:
				enemy.pos = Vector2(-50, 0)
				enemy.path = [enemy.pos, Vector2.ZERO]
				enemy.segment = 1
				enemy.hp = 100000.0
				enemy.stun_until = 1000.0
			for region in g.data.regions.values():
				region.timer = 1000.0
			g.combat.tick(Balance.STEP)
			var label := "%s / %s" % [kind, mode]
			suite.check(g.combat.effects.filter(func(fx): return fx.kind == "shot")[0].target_id == a.id, label + " initially chooses the selected enemy")
			# Make the other enemy preferable under each targeting mode.
			b.pos = Vector2(-90 if mode == "last" else -20, 0)
			b.hp = 200000.0
			tower.cooldown = 0.0
			g.combat.effects.clear()
			g.combat.tick(Balance.STEP)
			var expected: int = a.id if mode == "most_hp" else b.id
			suite.check(g.combat.effects.filter(func(fx): return fx.kind == "shot")[0].target_id == expected, label + " locks only Most HP; First and Last switch with priority")
			if mode != "most_hp":
				suite.check(not g.combat.target_locks.has(id), label + " never retains a target lock")
				continue
			a.dead = true
			tower.cooldown = 0.0
			g.combat.tick(Balance.STEP)
			suite.check(g.combat.target_locks.get(id) == b.id, label + " acquires a replacement after defeat")
			# A target leaving during cooldown must release the lock immediately.
			b.pos = Vector2(-1000, 0)
			tower.cooldown = 10.0
			g.combat.tick(Balance.STEP)
			suite.check(not g.combat.target_locks.has(id), label + " releases an out-of-range target during cooldown")
			b.pos = Vector2(-50, 0)
			tower.cooldown = 0.0
			g.combat.tick(Balance.STEP)
			suite.check(g.combat.target_locks.get(id) == b.id, label + " reacquires an available enemy")
			# Changing away from Most HP immediately restores positional priority.
			var c: Dictionary = suite.fixture_enemy(g, "heavy")
			c.pos = Vector2(-10, 0)
			c.path = [c.pos, Vector2.ZERO]
			c.segment = 1
			c.hp = 100000.0
			c.stun_until = 1000.0
			tower.target_mode = "first"
			tower.cooldown = 0.0
			g.combat.effects.clear()
			g.combat.tick(Balance.STEP)
			suite.check(not g.combat.target_locks.has(id) and g.combat.effects.filter(func(fx): return fx.kind == "shot")[0].target_id == c.id, label + " releases lock when changing to First")
