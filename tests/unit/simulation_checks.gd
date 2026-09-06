extends RefCounted

static func run(suite: SceneTree) -> void:
	test_all_territories(suite)
	test_crowded_spawning(suite)
	test_large_world(suite)
	test_long_idle(suite)

static func test_all_territories(suite: SceneTree) -> void:
	var g := VigilState.new(567)
	g.data.first_property_required = false # Already-owned legacy road fixture.
	g.data.towers.clear() # This fixture checks defenses of the actual rift tiles.
	g.combat.rng.seed = 567
	g.data.balance = 1.0e12
	for side in [-1, 1]:
		for i in range(1, 17):
			var id := "%d,0" % (side * i)
			g.data.regions[id] = VigilWorld.make_region(id, "%d,0" % (side * (i-1)), int(g.data.seed))
			g.data.regions[id].style = "forest" # Legacy basic-mob income fixture, including castle coordinates.
			g.refresh_paths() # Preserve the full legacy road fixture through ruins.
			# Center spawns travel inward; defend the road toward the core.
			suite.check(g.economy.build("rapid", id, 1 if side < 0 else 0) != "", "Can defend rift " + id)
	suite.advance(g, 0.5)
	var sources := {}
	for enemy in g.combat.enemies:
		sources[enemy.source] = true
	suite.check(sources.size() == 32, "All 32 rifts spawn immediately, including new rifts with no production history")
	suite.advance(g, 30)
	for r in g.data.regions.values():
		if VigilWorld.has_rift(r.id):
			suite.check(r.history_time > 30.0 and not r.history.is_empty(), "Rift %s continuously simulates real defeats" % r.id)
	for tower in g.data.towers.values():
		suite.check(tower.earnings > 0.0, "Tower %s earns across both sides of the territory" % tower.id)
	suite.check(g.economy.unclaimed() == g.data.kills * 5.0, "World-wide earnings equal actual kill rewards exactly")
	suite.check(is_equal_approx(g.combat.income_rate(), g.economy.unclaimed() / g.combat.simulation_time), "Gold per second includes all actual territory earnings once")
	var tower_id := g.economy.tower_at("16,0", 0)
	var before: float = g.data.towers[tower_id].earnings
	for i in range(Balance.MAX_TOWER_LEVEL - 1):
		g.economy.upgrade(tower_id)
	for i in range(Balance.MAX_TRAFFIC_LEVEL):
		g.economy.buy_traffic("16,0")
	suite.advance(g, 30)
	suite.check(g.data.towers[tower_id].earnings - before > before, "Distant traffic and tower upgrades improve actual income without a camera visit")
	suite.check(g.economy.unclaimed() == g.data.lifetime_earnings and g.data.lifetime_earnings == g.data.kills * 5.0, "Upgraded distant income has no estimated or duplicate payouts")
	print("PASS GROUP: all 33 territories spawn, fight, upgrade, and earn concurrently")

static func test_crowded_spawning(suite: SceneTree) -> void:
	var g := VigilState.new(568)
	g.data.balance = 10000.0
	g.data.towers.clear()
	g.expand("1,0")
	for i in range(901):
		g.combat.spawn("1,0", "heavy")
	var first: Dictionary = g.combat.enemies[0]
	var position: Vector2 = first.pos
	for r in g.data.regions.values():
		r.timer = 0.0
	g.combat.tick(Balance.STEP)
	suite.check(g.combat.enemy_serial == 902 and g.combat.enemies.size() == 902, "Every rift still spawns above the former 900-enemy limit")
	suite.check(not first.dead and first.pos != position, "Existing distant enemies keep their identity and continue moving")
	suite.check(g.data.kills == 0 and g.economy.unclaimed() == 0.0, "Spawning and moving enemies never award unearned gold")
	print("PASS GROUP: crowded worlds do not suppress rifts or retire live enemies")

static func test_large_world(suite: SceneTree) -> void:
	var g := VigilState.new(570)
	g.combat.rng.seed = 570
	g.data.balance = 1.0e12
	g.data.towers.clear()
	for side in [-1, 1]:
		for i in range(1, 41):
			var id := "%d,0" % (side * i)
			g.data.regions[id] = VigilWorld.make_region(id, "%d,0" % (side * (i-1)), int(g.data.seed))
			g.refresh_paths()
	for r in g.data.regions.values():
		r.traffic = Balance.MAX_TRAFFIC_LEVEL
		r.unlocks = Balance.UNLOCK_COSTS.keys()
	var started := Time.get_ticks_usec()
	var slowest := 0
	for i in range(600):
		var tick_start := Time.get_ticks_usec()
		g.combat.tick(Balance.STEP)
		slowest = maxi(slowest, Time.get_ticks_usec() - tick_start)
	var elapsed := Time.get_ticks_usec() - started
	var expected_minimum := 80 * int(floor(30.0 / Balance.traffic_period(Balance.MAX_TRAFFIC_LEVEL)))
	suite.check(g.data.regions.size() == 81 and g.combat.enemy_serial >= expected_minimum, "All 80 rifts surrounding the core sustain the configured spawn rate")
	suite.check(g.combat.enemies.size() > 2000, "Large worlds keep thousands of simultaneous enemies alive")
	suite.check(g.combat.enemy_serial == g.data.escapes + g.combat.enemies.size(), "Every spawned enemy is still alive or actually escaped; none are silently retired")
	suite.check(g.data.kills == 0.0 and g.economy.unclaimed() == 0.0, "Undefended high-traffic territory earns no estimated gold")
	print("PASS GROUP: 81 max-traffic rifts; %d live enemies; mean %.2f ms, slowest %.2f ms per 50 ms tick" % [g.combat.enemies.size(), elapsed / 600000.0, slowest / 1000.0])

static func test_long_idle(suite: SceneTree) -> void:
	var g := VigilState.new(606)
	g.combat.rng.seed = 606
	g.data.balance = 5000
	g.expand("-1,0")
	g.economy.build("splash", "0,0", 2)
	g.economy.build("heavy", "0,0", 1)
	g.economy.unlock("-1,0", "fast")
	g.economy.unlock("-1,0", "heavy")
	g.economy.buy_traffic("-1,0")
	var max_live := 0
	var max_effects := 0
	for i in range(72000): # One simulated hour at fixed 20 Hz.
		g.combat.tick(Balance.STEP)
		max_live = maxi(max_live, g.combat.enemies.size())
		max_effects = maxi(max_effects, g.combat.effects.size())
	suite.check(g.data.kills > 500, "One unattended hour produces sustained kills with slower, tougher traffic")
	suite.check(g.economy.unclaimed() == g.data.lifetime_earnings, "One-hour earnings reconcile exactly")
	suite.check(max_live < 100 and max_effects <= 100, "One-hour live objects and effects stay bounded")
	suite.check(g.combat.income_events.size() < 300, "Production event history stays bounded")
	suite.check(g.combat.enemy_pool.size() <= 128 and g.combat.enemy_pool.size() > 0, "Transient enemy reuse pool stays bounded")
	suite.check(g.data.balance >= 0 and is_finite(g.economy.unclaimed()), "One-hour balances stay valid")
	var before: float = g.data.balance
	suite.check(g.economy.buy_automation(), "Steward automation unlocks")
	suite.advance(g, 1)
	suite.check(g.economy.unclaimed() == 0 and g.data.balance > before, "Automation collects stored and new income")
	print("PASS GROUP: one simulated hour; %d kills, peak %d enemies, %d effects" % [g.data.kills, max_live, max_effects])
