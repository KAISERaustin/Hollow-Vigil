extends RefCounted

static func run(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		var game := VigilState.new(716)
		game.data.balance = 10000.0
		game.expand("1,0")
		game.data.regions["1,0"].timer = 100.0
		var id := game.economy.build(kind, "0,0", 0)
		var target := game.combat.spawn("1,0", "heavy")
		var neighbor := game.combat.spawn("1,0", "heavy")
		var position := VigilWorld.pad_position("0,0", 0) + Vector2(75, 0)
		for enemy in [target, neighbor]:
			enemy.pos = position
			enemy.path = [position, position + Vector2(1000, 0)]
		game.combat.tick(Balance.STEP)
		var stats := Balance.stats(kind, 1)
		suite.check(target.hp == 85.0 - stats.damage, kind + " still resolves its original damage on the combat tick")
		suite.check(neighbor.hp == (85.0 - stats.damage if kind == "splash" else 85.0), kind + " preserves its single-target or splash behavior")
		var shots := game.combat.effects.filter(func(fx): return fx.kind == "shot")
		suite.check(shots.size() == 1, kind + " emits one visual per attack")
		if shots.is_empty():
			continue
		var fx: Dictionary = shots[0]
		suite.check(fx.tower_kind == kind and fx.life == fx.max_life and fx.flight > Balance.STEP, kind + " launches its own traveling effect from age zero")
		var impact: Vector2 = fx.pos
		game.combat.hit(target, 1000.0, id)
		game.combat.recycle_dead_enemies()
		game.combat.spawn("1,0", "basic")
		suite.check(fx.pos == impact, kind + " keeps a stable destination when the enemy pool reuses a defeated target")
		game.combat.enemies.clear()
		var credited: float = game.data.towers[id].earnings
		for i in range(20):
			game.combat.tick(Balance.STEP)
		suite.check(game.combat.effects.is_empty() and game.data.towers[id].earnings == credited, kind + " effects expire without issuing another payout")
	# Compare normal effects with a saturated visual pool under identical combat.
	var normal := fixture()
	var saturated := fixture()
	for i in range(100):
		saturated.combat.add_effect({"kind": "death", "pos": Vector2.ZERO, "life": 100.0, "max_life": 100.0, "color": "ffffff"})
	for i in range(200):
		normal.combat.tick(Balance.STEP)
		saturated.combat.tick(Balance.STEP)
	suite.check(saturated.combat.effects.size() <= 100, "Traveling attacks respect the shared effect limit")
	suite.check(normal.data.towers == saturated.data.towers and normal.data.kills == saturated.data.kills and normal.combat.enemies == saturated.combat.enemies, "A full effect pool cannot change targeting, damage, cooldowns, or earnings")
	print("PASS GROUP: distinct attack effects, recycled targets, unchanged combat and bounded visuals")

static func fixture() -> VigilState:
	var game := VigilState.new(711)
	game.combat.rng.seed = 81
	game.data.balance = 10000.0
	game.data.last_accounted = 1000.0
	game.expand("1,0")
	for pad in range(3):
		game.economy.build(["rapid", "splash", "heavy"][pad], "1,0", pad)
	return game
