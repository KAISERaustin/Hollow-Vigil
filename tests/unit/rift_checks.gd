extends RefCounted

static func run(suite: SceneTree) -> void:
	var game := VigilState.new(819)
	game.data.balance = 100000.0
	game.expand("1,0")
	game.expand("2,0")
	for region in game.data.regions.values():
		region.timer = 1000.0
	for style in VigilWorld.STYLES:
		game.data.regions["2,0"].style = style
		for kind in Balance.NORMAL_KINDS:
			game.combat.enemies.clear()
			var enemy := game.combat.spawn("2,0", kind)
			var base: Dictionary = Balance.ENEMIES[kind]
			var health: float = base.hp * (1.25 if style == "ashen_forge" else 1.0)
			suite.check(is_equal_approx(enemy.max_hp, health) and enemy.hp == enemy.max_hp, style + " applies health to " + kind)
			enemy.hp = health * 0.5
			var start: Vector2 = enemy.pos
			game.combat.tick(Balance.STEP)
			var speed: float = base.speed * (1.15 if style == "drowned_crypt" else 1.0)
			suite.check(absf(start.distance_to(enemy.pos) - speed * Balance.STEP) < 0.001, style + " movement for " + kind)
			var regen: float = health * 0.01 * Balance.STEP if style == "bloodmoon_sanctuary" else 0.0
			suite.check(is_equal_approx(enemy.hp, health * 0.5 + regen), style + " healing for " + kind)
			# Origin is retained even after leaving its tile and passing another rift.
			enemy.pos = VigilWorld.center("1,0")
			game.data.regions["1,0"].style = "ashen_forge"
			suite.check(enemy.rift_style == style, "Crossing a tile cannot replace or stack the source effect")
	game.combat.enemies.clear()
	game.data.regions["2,0"].style = "ashen_forge"
	var forged := game.combat.spawn("2,0", "basic")
	forged.hp *= 0.4
	game.set_balance_stat("rifts", "ashen_forge", "strength", 50.0)
	suite.check(is_equal_approx(forged.max_hp, Balance.ENEMIES.basic.hp * 1.5) and is_equal_approx(forged.hp / forged.max_hp, 0.4), "Live health bonus preserves damage fraction")
	game.set_balance_stat("enemies", "basic", "hp", 200.0)
	suite.check(forged.max_hp == 300.0 and is_equal_approx(forged.hp, 120.0), "Enemy health tuning composes with the rift bonus")
	game.set_balance_stat("rifts", "ashen_forge", "strength", 0.0)
	suite.check(forged.max_hp == 200.0, "Zero disables forged bonus live")
	game.reset_developer_balance()
	suite.check(is_equal_approx(forged.max_hp, Balance.ENEMIES.basic.hp * 1.25), "Reset restores default rift bonus")
	game.combat.enemies.clear()
	game.data.regions["2,0"].style = "bloodmoon_sanctuary"
	var blood := game.combat.spawn("2,0", "basic")
	blood.hp -= 0.001
	game.combat.tick(Balance.STEP)
	suite.check(blood.hp == blood.max_hp, "Regeneration cannot exceed full health")
	blood.hp *= 0.5
	game.set_balance_stat("rifts", "bloodmoon_sanctuary", "strength", 0.0)
	var before: float = blood.hp
	game.combat.tick(Balance.STEP)
	suite.check(blood.hp == before, "Zero disables regeneration live")
	blood.dead = true
	game.combat.tick(Balance.STEP)
	game.data.regions["2,0"].style = "forest"
	var recycled := game.combat.spawn("2,0", "basic")
	suite.check(recycled.rift_style == "forest" and recycled.hp == Balance.ENEMIES.basic.hp, "Recycled grass enemies inherit no old effect")
	game.combat.enemies.clear()
	game.data.regions["2,0"].style = "drowned_crypt"
	var drowned := game.combat.spawn("2,0", "basic")
	game.set_balance_stat("rifts", "drowned_crypt", "strength", 50.0)
	drowned.slow_until = game.combat.simulation_time + 10.0
	var start: Vector2 = drowned.pos
	game.combat.tick(Balance.STEP)
	suite.check(absf(start.distance_to(drowned.pos) - Balance.ENEMIES.basic.speed * 1.5 * 0.75 * Balance.STEP) < 0.001, "Live speed bonus respects slows")
	drowned.stun_until = game.combat.simulation_time + 10.0
	start = drowned.pos
	game.combat.tick(Balance.STEP)
	suite.check(start == drowned.pos, "Rift speed does not bypass stun")
	suite.check(not game.set_balance_stat("rifts", "forest", "strength", 20.0), "Grass cannot receive a developer bonus")
	suite.check(not game.set_balance_stat("rifts", "ashen_forge", "strength", -1.0), "Negative rift strengths rejected")
	game.save_path = "user://rift-effects-test.save"
	for region in game.data.regions.values():
		region.timer = 1.0
	suite.clean_test_save(game.save_path)
	suite.check(game.save(), "Rift settings save")
	var loaded := VigilState.new(10)
	loaded.save_path = game.save_path
	suite.check(loaded.load_save() and loaded.tuning == game.tuning, "Rift controls persist across reload")
	suite.clean_test_save(game.save_path)
	print("PASS GROUP: biome effects, live controls, pooling, crowd control, and persistence")
