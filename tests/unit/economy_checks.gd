extends RefCounted

static func run(suite: SceneTree) -> void:
	test_first_loop(suite)
	test_transactions(suite)

static func test_first_loop(suite: SceneTree) -> void:
	for direction in VigilWorld.DIRS:
		var start := VigilState.new(123)
		suite.check(start.expand(VigilWorld.key(direction)), "First territory is affordable in every direction")
		var pad := 1 if direction.x < 0 else (2 if direction.y < 0 else 0)
		suite.check(start.economy.build("rapid", VigilWorld.key(direction), pad) != "", "Remaining starting gold funds a defense on the new route")
		suite.advance(start, 60)
		suite.check(start.data.kills > 0, "Affordable defense earns from first territory %s" % direction)
	var g := VigilState.new(123)
	suite.check(g.data.towers.is_empty() and g.data.balance == Balance.STARTING_GOLD, "New player starts with empty slots and gold")
	for kind in Balance.TOWERS:
		suite.check(g.economy.build(kind, "0,0", 0) == "" and g.data.balance == Balance.STARTING_GOLD and g.data.next_tower == 1, "First property requirement blocks every tower without spending gold")
	suite.advance(g, 5)
	suite.check(g.combat.enemies.is_empty() and g.combat.enemy_serial == 0, "Core-only start has no enemy spawns")
	suite.check(g.combat.spawn("0,0").is_empty(), "Core cannot spawn enemies even when requested directly")
	suite.check(not g.economy.buy_traffic("0,0") and not g.economy.unlock("0,0", "fast"), "Core has no purchasable rift upgrades")
	suite.check(g.expand("-1,0"), "Starting gold purchases the first territory")
	# This payout fixture measures base enemies independently of seeded biomes.
	g.data.regions["-1,0"].style = "forest"
	# A biome boss can now awaken on the purchased tile; it is not a base wave.
	g.combat.enemies.clear()
	suite.check(g.economy.build("rapid", "0,0", 0) == "1", "Player buys their first tower after purchasing property")
	suite.check(g.data.balance == Balance.STARTING_GOLD - Balance.expansion_cost(1) - Balance.TOWERS.rapid.cost, "Property and first tower charge full price")
	suite.check(g.paths["-1,0"][0] == VigilWorld.center("-1,0"), "First purchased rift spawns at its tile center")
	suite.advance(g, 45)
	suite.check(g.data.kills >= 5, "Starter tower earns gold against tougher enemies in 45 seconds")
	suite.check(g.economy.unclaimed() == g.data.kills * 5.0, "Every basic kill pays exactly five gold")
	suite.check(g.data.balance == 120.0, "Defeats accumulate rather than silently auto-collect")
	var earned := g.economy.unclaimed()
	suite.check(g.economy.collect() == earned and g.data.balance == 120 + earned, "Collection funds spendable balance immediately")
	suite.check(g.data.lifetime_earnings == earned, "Collection does not increase lifetime earnings")
	var old := Balance.stats("rapid", 1)
	suite.check(g.economy.upgrade("1", 1), "First meaningful upgrade is affordable")
	var upgraded := Balance.stats("rapid", 2)
	suite.check(upgraded.damage > old.damage and upgraded.period < old.period and upgraded.range > old.range, "Upgrade improves damage, speed, and reach")
	suite.check(not g.economy.upgrade("1", 1), "Repeated stale upgrade action does not charge again")
	# Continuous rifts vary each interval by up to ten percent. Assert the
	# guaranteed count, rather than depending on randomly short intervals.
	var born := g.combat.enemy_serial
	suite.advance(g, 30)
	suite.check(g.combat.enemy_serial >= born + int(floor(30.0 / (g.economy.spawn_period("-1,0") * 1.1))), "Spawns continue with no wave break")
	suite.check(g.data.kills > earned / 5.0, "Combat keeps earning after an upgrade")
	print("PASS GROUP: first playable loop")

static func test_transactions(suite: SceneTree) -> void:
	var g: VigilState = suite.legacy_core_fixture(77)
	g.economy.build("rapid", "0,0", 0)
	var e: Dictionary = suite.fixture_enemy(g, "heavy")
	suite.check(g.combat.hit(e, Balance.ENEMIES.heavy.hp, "1"), "Lethal hit confirms death")
	suite.check(not g.combat.hit(e, Balance.ENEMIES.heavy.hp, "1"), "Simultaneous lethal hit sees dead flag")
	suite.check(g.data.kills == 1 and g.economy.unclaimed() == 24, "Duplicate hits award only one payout")
	var balance: float = g.data.balance
	suite.check(g.economy.collect("1") == 24 and g.economy.collect() == 0, "Individual then collect-all cannot duplicate")
	for i in range(100):
		g.economy.collect("1")
		g.economy.collect()
	suite.check(g.data.balance == balance + 24, "Rapid repeated collection stays exact")
	var tower := g.economy.build("splash", "0,0", 1)
	suite.check(tower != "", "Valid build commits")
	balance = g.data.balance
	suite.check(g.economy.build("heavy", "0,0", 1) == "" and g.data.balance == balance, "Duplicate placement cannot charge")
	suite.check(g.economy.build("rapid", "missing", 0) == "" and g.economy.build("rapid", "0,0", VigilWorld.MAX_GROUND_PAD + 1) == "", "Invalid placement is rejected")
	suite.check(not g.economy.spend(-1) and not g.economy.spend(NAN) and not g.economy.spend(INF), "Invalid costs are rejected")
	g.data.balance = 1
	suite.check(not g.economy.upgrade("1") and not g.expand("1,0") and g.data.balance == 1, "Unaffordable actions do not mutate balance")
	g.data.balance = 1.0e100
	g.economy.credit("1", 1.0e100)
	g.economy.collect()
	suite.check(is_finite(g.data.balance) and g.data.balance > 1.0e100, "Large balances remain finite")
	suite.check(Balance.money(g.data.balance).contains("e"), "Large values use readable scientific notation")
	suite.check(Balance.money(INF) == "0", "Formatter safely handles invalid values")
	print("PASS GROUP: transaction integrity")
