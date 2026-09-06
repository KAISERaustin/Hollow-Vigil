extends RefCounted

const SaveFixtures = preload("res://tests/unit/review_regressions.gd")

static func run(suite: SceneTree) -> void:
	test_progression(suite)
	test_attack_intervals(suite)
	test_legacy_migration(suite)
	print("PASS GROUP: three tower levels, investment limits, attack cadence, legacy refunds and migration recovery")

static func test_progression(suite: SceneTree) -> void:
	var prices := {"rapid": [60.0, 60.0, 100.0], "splash": [120.0, 120.0, 200.0], "heavy": [160.0, 140.0, 220.0], "electric": [140.0, 120.0, 200.0]}
	suite.check(Balance.MAX_TOWER_LEVEL == 4, "Every tower has four total levels")
	for kind in Balance.TOWERS:
		var g: VigilState = suite.legacy_core_fixture(314)
		g.data.balance = 1000.0
		var id := g.economy.build(kind, "0,0", 0)
		var invested: float = prices[kind][0]
		suite.check(g.data.balance == 1000.0 - invested and g.data.towers[id].level == 1, "%s starts at level one for its build price" % kind)
		for level in [1, 2]:
			var price: float = prices[kind][level]
			suite.check(Balance.upgrade_cost(g.data.towers[id]) == price, "%s level %d quote matches the planned gold investment" % [kind, level + 1])
			g.data.balance = price - 0.01
			var before := g.data.duplicate(true)
			suite.check(not g.economy.upgrade(id, level) and g.data == before, "Insufficient gold cannot partially upgrade %s" % kind)
			g.data.balance = price
			suite.check(g.economy.upgrade(id, level) and g.data.balance == 0.0 and g.data.towers[id].level == level + 1, "Exact gold buys one %s upgrade" % kind)
			invested += price
			suite.check(Balance.sell_refund(g.data.towers[id]) == floor(invested * 0.5), "%s sale accounts for the actual tier prices" % kind)
			before = g.data.duplicate(true)
			suite.check(not g.economy.upgrade(id, level) and g.data == before, "Stale %s upgrade cannot charge twice" % kind)
			var old := Balance.stats(kind, level)
			var upgraded := Balance.stats(kind, level + 1)
			suite.check(upgraded.damage > old.damage and upgraded.period < old.period and upgraded.range > old.range, "Each %s tier improves damage, attack speed and reach" % kind)
			if kind == "splash":
				suite.check(upgraded.splash > old.splash, "Pyre tiers grow their area damage")
		g.data.balance = Balance.MAX_MONEY
		var capped := g.data.duplicate(true)
		for attempt in range(5):
			suite.check(not g.economy.upgrade(id) and g.data == capped, "%s requires an explicit branch beyond level three" % kind)
		suite.check(Balance.upgrade_cost(g.data.towers[id]) > 0.0, "Level three %s offers a branch price" % kind)
		suite.check(Balance.stats(kind, 10000) == Balance.stats(kind, 3) and Balance.stats(kind, 0) == Balance.stats(kind, 1), "Stats cannot extrapolate beyond the three %s tiers" % kind)
		suite.check(g.storage.valid_data(g.data), "Maximum %s remains saveable" % kind)
		g.data.towers[id].level = 4
		suite.check(not g.storage.valid_data(g.data), "Current saves reject a branchless fourth %s level" % kind)
	var heavy_hp: float = Balance.ENEMIES.heavy.hp
	for level in [1, 2, 3]:
		suite.check(int(ceil(heavy_hp / Balance.stats("heavy", level).damage)) == [9, 6, 4][level - 1], "Obelisk upgrades reduce Revenant hits from nine to six to four")
	suite.check(int(ceil(Balance.ENEMIES.basic.hp / Balance.stats("rapid", 1).damage)) == 8 and int(ceil(Balance.ENEMIES.basic.hp / Balance.stats("rapid", 3).damage)) == 3, "Ashneedle upgrades reduce Hollow hits from eight to three")
	suite.check(int(ceil(heavy_hp / Balance.stats("splash", 3).damage)) == 10, "Maximum Pyre needs ten blasts per Revenant, preserving Obelisk's burst role")

static func test_attack_intervals(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		for level in [1, 2, 3]:
			var g := VigilState.new(314)
			g.data.balance = 10000.0
			g.expand("-1,0")
			g.data.regions["-1,0"].timer = 10.0
			var id := g.economy.build(kind, "0,0", 0)
			g.data.towers[id].level = level
			var enemy := g.combat.spawn("-1,0", "heavy")
			enemy.hp = 10000.0
			var pos := VigilWorld.pad_position("0,0", 0)
			enemy.path = [pos, pos + Vector2(10000, 0)]
			enemy.pos = pos
			var stats := Balance.stats(kind, level)
			g.combat.tick(Balance.STEP)
			suite.check(is_equal_approx(enemy.hp, 10000.0 - (stats.damage if kind == "electric" else 0.0)), "First %s level %d shot respects flight timing" % [kind, level])
			var ticks := int(ceil(stats.period / Balance.STEP - 0.000001))
			for tick in range(ticks - 1):
				g.combat.tick(Balance.STEP)
			suite.check(is_equal_approx(enemy.hp, 10000.0 - stats.damage) and g.data.towers[id].cooldown > 0.000001, "%s level %d lands its first shot without firing early" % [kind, level])
			g.combat.tick(Balance.STEP)
			suite.check(is_equal_approx(g.data.towers[id].cooldown, stats.period), "%s level %d fires without an extra tick from floating-point residue" % [kind, level])
			if kind != "electric":
				g.combat.tick(g.combat.pending_shots[0].remaining)
			suite.check(is_equal_approx(enemy.hp, 10000.0 - 2.0 * stats.damage), "%s level %d lands its second tier-damage shot" % [kind, level])

static func test_legacy_migration(suite: SceneTree) -> void:
	var path := "user://tower-migration-test.save"
	suite.clean_test_save(path)
	var source := VigilState.new(314)
	source.data.balance = 10000.0
	source.expand("-1,0")
	var rapid := source.economy.build("rapid", "0,0", 0)
	var splash := source.economy.build("splash", "0,0", 1)
	var heavy := source.economy.build("heavy", "0,0", 2)
	var low := source.economy.build("rapid", "0,0", 3)
	var legacy := source.data.duplicate(true)
	legacy.version = 1
	legacy.last_accounted = 1000.0
	legacy.balance = 123.5
	legacy.reserve = 7.25
	legacy.settings.future_setting = true
	legacy.towers[rapid].level = 6
	legacy.towers[splash].level = 4
	legacy.towers[heavy].level = 5
	legacy.towers[low].level = 2
	legacy.towers[rapid].earnings = 17.5
	legacy.regions["-1,0"].history = {rapid: 900.0, low: 60.0}
	legacy.regions["-1,0"].history_time = 60.0
	var before := legacy.duplicate(true)
	SaveFixtures.write_candidate(path, legacy)
	var migrated := source.storage.read_candidate(path)
	suite.check(not migrated.is_empty(), "Checksummed version-one towers above level three remain recoverable")
	if migrated.is_empty():
		return
	# Old prices: rapid levels 4/5/6 = 101+157+243, Pyre 4 = 202,
	# Obelisk 4/5 = 270+418. Refund removed upgrades in full, once.
	var expected_balance := 123.5 + 501.0 + 202.0 + 688.0
	suite.check(migrated.balance == expected_balance and migrated.version == Balance.VERSION, "Migration refunds the original rounded prices for removed upgrades")
	suite.check(migrated.towers[rapid].level == 3 and migrated.towers[splash].level == 3 and migrated.towers[heavy].level == 3 and migrated.towers[low].level == 2, "Migration caps every old tower while preserving lower levels")
	suite.check(migrated.reserve == 7.25 and migrated.towers[rapid].earnings == 17.5 and migrated.settings.future_setting, "Migration preserves stored gold and unrelated settings")
	suite.check(migrated.regions["-1,0"].history == {low: 60.0}, "Capped production is relearned without changing unaffected production")
	suite.check(legacy == before and source.storage.read_candidate(path) == migrated, "Candidate migration is pure and repeatable")
	var loaded := VigilState.new()
	loaded.save_path = path
	suite.check(loaded.load_save(1000.0) and loaded.data.balance == expected_balance, "Loading commits migrated currency and the level cap")
	var again := VigilState.new()
	again.save_path = path
	suite.check(again.load_save(1000.0) and again.data.balance == expected_balance, "Reopening cannot refund the same removed upgrades twice")
	# Recovery must choose the newer migrated temporary file over the primary.
	legacy.sequence = again.data.sequence + 10
	legacy.balance = 200.0
	SaveFixtures.write_candidate(path + ".tmp", legacy)
	suite.check(again.load_save(1000.0) and again.data.balance == expected_balance + 76.5, "Interrupted legacy migration preserves sequence-based recovery")
	for level in [1, 2, 3, 10000]:
		var edge := before.duplicate(true)
		edge.towers[rapid].level = level
		SaveFixtures.write_candidate(path, edge)
		var read := source.storage.read_candidate(path)
		suite.check(not read.is_empty() and read.towers[rapid].level == mini(level, 3) and is_finite(read.balance), "Legacy level %d migrates safely" % level)
	for level in [0, 1.5, 10001, "3"]:
		var invalid := before.duplicate(true)
		invalid.towers[rapid].level = level
		SaveFixtures.write_candidate(path, invalid)
		suite.check(source.storage.read_candidate(path).is_empty(), "Migration rejects malformed old levels before refunding")
	var future := before.duplicate(true)
	future.version = Balance.VERSION + 1
	SaveFixtures.write_candidate(path, future)
	suite.check(source.storage.read_candidate(path).is_empty(), "Unknown future versions are never reinterpreted as old progress")
	suite.clean_test_save(path)
