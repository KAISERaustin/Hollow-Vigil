extends RefCounted

static func run(suite: SceneTree) -> void:
	test_impact_timing(suite)
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
		suite.check(target.hp == Balance.ENEMIES.heavy.hp - (stats.damage if kind == "electric" else 0.0), kind + " applies launch damage only for instant lightning")
		suite.check(neighbor.hp == (Balance.ENEMIES.heavy.hp - stats.damage if kind == "electric" else Balance.ENEMIES.heavy.hp), kind + " does not apply splash before arrival")
		var shots := game.combat.effects.filter(func(fx): return fx.kind == "shot")
		suite.check(shots.size() == (2 if kind == "electric" else 1), kind + " emits the expected visuals per attack")
		if shots.is_empty():
			continue
		var fx: Dictionary = shots[0]
		suite.check(fx.tower_kind == kind and fx.life == fx.max_life and (fx.flight == 0.0 if kind == "electric" else fx.flight > Balance.STEP), kind + " launches its own traveling effect from age zero")
		var launch_center: Vector2 = fx.pos
		game.combat.tick(Balance.STEP)
		suite.check(fx.pos == target.pos and fx.pos != launch_center, kind + " follows the moving target center during flight")
		# Cross a corner on the next tick; tracking must use the route's actual position.
		var corner: Vector2 = target.pos + Vector2(0.1, 0)
		target.path = [target.pos, corner, corner + Vector2(0, 1000)]
		target.segment = 1
		game.combat.tick(Balance.STEP)
		suite.check(fx.pos == target.pos and fx.pos.y > corner.y, kind + " follows the target through a route turn")
		var impact: Vector2 = fx.pos
		game.combat.hit(target, 1000.0, id)
		game.combat.recycle_dead_enemies()
		var replacement := game.combat.spawn("1,0", "basic")
		replacement.pos = impact + Vector2(300, 0)
		game.combat.tick(Balance.STEP)
		suite.check(fx.pos == impact and not fx.has("target_id"), kind + " keeps a stable destination when the enemy pool reuses a defeated target")
		suite.check(replacement.hp == replacement.max_hp, kind + " cannot damage a recycled replacement with an old shot")
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
	print("PASS GROUP: impact timing, recycled targets, and bounded visuals")

static func test_impact_timing(suite: SceneTree) -> void:
	for kind in ["rapid", "heavy", "splash"]:
		var game := VigilState.new(718)
		game.data.balance = 10000.0
		game.expand("1,0")
		game.data.regions["1,0"].timer = 100.0
		var id := game.economy.build(kind, "0,0", 0)
		var target := game.combat.spawn("1,0", "heavy")
		target.pos = VigilWorld.pad_position("0,0", 0) + Vector2(75, 0)
		target.path = [target.pos, target.pos + Vector2(1000, 0)]
		var hp: float = target.hp
		game.combat.tick(Balance.STEP)
		game.data.towers[id].cooldown = 100.0
		var fx: Dictionary = game.combat.effects[0]
		game.combat.tick(fx.flight - 0.001)
		suite.check(target.hp == hp and game.data.kills == 0 and game.data.towers[id].earnings == 0.0, kind + " preserves health and rewards until arrival")
		game.combat.tick(0.001)
		suite.check(target.hp == hp - Balance.stats(kind, 1).damage and fx.pos == target.pos, kind + " damages the moving enemy exactly at impact")
		var impact: Vector2 = fx.pos
		game.combat.tick(Balance.STEP)
		suite.check(target.hp == hp - Balance.stats(kind, 1).damage and fx.pos == impact, kind + " applies damage once and anchors impact feedback")
		# A lethal shot also delays removal and credit until its arrival.
		target.hp = Balance.stats(kind, 1).damage
		game.data.towers[id].cooldown = 0.0
		game.combat.tick(Balance.STEP)
		suite.check(not target.dead and game.data.kills == 0, kind + " leaves lethal targets alive during flight")
		game.data.towers[id].cooldown = 100.0
		game.combat.tick(game.combat.pending_shots[0].remaining)
		suite.check(target.dead and game.data.kills == 1 and game.data.towers[id].earnings == Balance.ENEMIES.heavy.payout, kind + " awards a lethal impact exactly once")
	test_splash_arrival(suite)

static func test_splash_arrival(suite: SceneTree) -> void:
	var game := VigilState.new(720)
	game.data.balance = 10000.0
	game.expand("1,0")
	game.data.regions["1,0"].timer = 100.0
	var id := game.economy.build("splash", "0,0", 0)
	var center := VigilWorld.pad_position("0,0", 0) + Vector2(75, 0)
	var victims: Array[Dictionary] = []
	for offset in [0.0, 5.0, 250.0]:
		var enemy := game.combat.spawn("1,0", "heavy")
		enemy.pos = center + Vector2(offset, 0)
		enemy.path = [enemy.pos, enemy.pos + Vector2(1000, 0)]
		victims.append(enemy)
	game.combat.tick(Balance.STEP)
	game.data.towers[id].cooldown = 100.0
	victims[1].pos = center + Vector2(250, 0)
	victims[2].pos = victims[0].pos
	game.combat.tick(game.combat.pending_shots[0].remaining)
	var damage: float = Balance.stats("splash", 1).damage
	suite.check(victims[0].hp == victims[0].max_hp - damage and victims[1].hp == victims[1].max_hp and victims[2].hp == victims[2].max_hp - damage, "Splash uses enemies inside the radius at impact, including arrivals and departures during flight")

static func fixture() -> VigilState:
	var game := VigilState.new(711)
	game.combat.rng.seed = 81
	game.data.balance = 10000.0
	game.data.last_accounted = 1000.0
	game.expand("1,0")
	for pad in range(4):
		game.economy.build(["rapid", "splash", "heavy", "electric"][pad], "1,0", pad)
	return game
