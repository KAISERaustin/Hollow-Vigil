extends "res://tests/test_runner.gd"

func run() -> void:
	var game := VigilState.new(570)
	game.data.first_property_required = false
	game.data.balance = 1.0e12
	game.combat.rng.seed = 570
	var kinds := ["ironspike", "moonwheel", "hex_lantern", "caltrop_keep"]
	for side in [-1, 1]:
		for index in range(1, 21):
			var region := "%d,0" % (side * index)
			game.data.regions[region] = VigilWorld.make_region(region, "%d,0" % (side * (index - 1)), int(game.data.seed))
			game.data.regions[region].style = "forest"
			game.refresh_paths()
			var kind: String = kinds[(index - 1) % 4]
			var stage := int((index - 1) / 4.0)
			var id := game.economy.build(kind, region, 1 if side < 0 else 0)
			check(not id.is_empty(), "Distant expansion builds " + kind)
			for level in range(1, mini(stage + 1, 4)):
				game.economy.upgrade(id, level, Balance.BRANCHES[kind].keys()[stage - 3] if level == 3 else "")
	for region in game.data.regions.values():
		region.traffic = Balance.MAX_TRAFFIC_LEVEL
		region.unlocks = Balance.UNLOCK_COSTS.keys()
	var start := Time.get_ticks_usec()
	for tick in range(600): game.combat.tick(Balance.STEP)
	var mean_ms := (Time.get_ticks_usec() - start) / 600000.0
	check(game.combat.enemy_serial > 1000, "All distant portals keep spawning with the new towers active")
	check(game.combat.enemy_serial == game.combat.enemies.size() + game.data.kills + game.data.escapes, "Every spawned enemy is live, defeated or escaped exactly once")
	check(game.data.kills > 0 and game.economy.unclaimed() == game.data.lifetime_earnings, "Offscreen tower income reconciles with actual rewards")
	for tower in game.data.towers.values():
		var owned := game.combat.traps.filter(func(trap): return trap.tower_id == tower.id)
		check(owned.size() <= int(Balance.tower_stats(tower).get("trap_capacity", 0)), "Every offscreen trap owner respects its capacity")
	check(game.combat.effects.size() <= 100 and game.combat.enemy_pool.size() <= 128, "Shared cosmetic and recycled-enemy pools remain bounded")
	print("TOWER EXPANSION STRESS: %d towers, %d enemies, %.2f ms mean tick; %d checks, %d failures" % [game.data.towers.size(), game.combat.enemies.size(), mean_ms, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
