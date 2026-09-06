extends RefCounted

static func run(suite: SceneTree) -> void:
	var g := VigilState.new(314)
	g.data.balance = 10000
	g.expand("1,0")
	g.data.regions["1,0"].style = "ashen_forge"
	g.set_balance_stat("rifts", "ashen_forge", "strength", 0.0) # Isolate the Keeper's base stats.
	g.data.balance = 139
	suite.check(not g.economy.unlock("1,0", "lantern") and g.data.balance == 139, "Keeper attunement rejects insufficient gold")
	g.data.balance = 10000
	suite.check(g.economy.unlock("1,0", "lantern") and g.data.balance == 9860, "Keeper attunement costs 140 gold")
	suite.check(not g.economy.unlock("1,0", "lantern") and g.data.balance == 9860, "Duplicate attunement cannot charge")
	suite.check(not g.data.regions["0,0"].unlocks.has("lantern"), "Attunement belongs only to its rift")
	for mask in range(1 << Balance.UNLOCK_COSTS.size()):
		var unlocks: Array = []
		var kinds := Balance.UNLOCK_COSTS.keys()
		for i in range(kinds.size()):
			if mask & (1 << i):
				unlocks.append(kinds[i])
		var counts := {}
		for i in range(1000):
			var kind := Balance.enemy_kind(unlocks, (i + 0.5) / 1000.0)
			counts[kind] = counts.get(kind, 0) + 1
		for kind in Balance.ENEMIES:
			var expected: float = Balance.enemy_mix(unlocks).get(kind, 0.0)
			suite.check(counts.get(kind, 0) == roundi(expected * 1000), "All attunement combinations preserve exact spawn shares: %s" % kind)
	g.combat.rng.seed = 14
	var seen := false
	for i in range(80):
		var spawned := g.combat.spawn("1,0")
		seen = seen or spawned.kind == "lantern"
		suite.check(spawned.kind in ["cinder_imp", "lantern"], "Rift spawns only attuned enemies")
	suite.check(seen, "Normal spawning includes the Keeper after attunement")
	g.combat.enemies.clear()
	var enemy := g.combat.spawn("1,0", "lantern")
	var origin: Vector2 = enemy.pos
	g.combat.tick(Balance.STEP)
	suite.check(is_equal_approx(enemy.pos.distance_to(origin), 46.0 * Balance.STEP), "Keeper moves at its configured speed")
	suite.check(enemy.hp == 120 and enemy.max_hp == 120, "Keeper spawns with full health")
	var tower := g.economy.build("heavy", "0,0", 0)
	suite.check(not g.combat.hit(enemy, 119, tower) and enemy.hp == 1, "Keeper survives nonlethal damage")
	suite.check(g.combat.hit(enemy, 1, tower), "Keeper takes lethal damage")
	suite.check(not g.combat.hit(enemy, 1, tower) and g.economy.unclaimed() == 14, "Keeper rewards exactly once")
	var path := "user://keeper-test.save"
	suite.clean_test_save(path)
	g.save_path = path
	suite.check(g.save(1000), "Keeper attunement saves")
	var loaded := VigilState.new()
	loaded.save_path = path
	suite.check(loaded.load_save(1000) and "lantern" in loaded.data.regions["1,0"].unlocks, "Keeper attunement survives reload")
	suite.clean_test_save(path)
	print("PASS GROUP: Lantern Keeper attunement, spawn mix, movement, rewards, save")
