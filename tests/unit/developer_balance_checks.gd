extends RefCounted

static func run(suite: SceneTree) -> void:
	test_validation_and_storage(suite)
	test_live_enemies(suite)
	test_towers(suite)
	print("PASS GROUP: developer balance validation, persistence, live combat, pricing and resets")

static func test_validation_and_storage(suite: SceneTree) -> void:
	var game := VigilState.new(55)
	game.save_path = "user://developer-balance.save"
	suite.clean_test_save(game.save_path)
	suite.check(game.tuning.is_empty() and game.storage.valid_data(game.data), "Saves without developer settings use defaults")
	for category in Balance.TUNING_FIELDS:
		for kind in Balance.definitions(category):
			for stat in Balance.TUNING_FIELDS[category]:
				var limits: Dictionary = Balance.TUNING_FIELDS[category][stat]
				for value in [limits.min, limits.max]:
					suite.check(game.set_balance_stat(category, kind, stat, value), "Every type accepts bounded " + stat)
					suite.check(Balance.tuned_value(category, kind, stat, game.tuning) == value, "Adjusted stat is read back")
				var before := game.data.duplicate(true)
				for invalid in [limits.min - 1.0, limits.max + 1.0, NAN, INF]:
					suite.check(not game.set_balance_stat(category, kind, stat, invalid) and before == game.data, "Invalid " + stat + " leaves state untouched")
	suite.check(game.storage.valid_data(game.data) and game.save(), "All slider maxima form a valid save")
	var loaded := VigilState.new(56)
	loaded.save_path = game.save_path
	suite.check(loaded.load_save() and loaded.tuning == game.tuning, "All enemy and tower settings survive reload")
	var fresh := VigilState.new(57)
	suite.check(fresh.tuning.is_empty() and Balance.stats("rapid", 1).damage == Balance.TOWERS.rapid.damage, "Custom values never leak to another game or shared defaults")
	var before := loaded.data.duplicate(true)
	for invalid in [[], {"unknown": {}}, {"enemies": []}, {"enemies": {"unknown": {}}}, {"towers": {"rapid": []}}, {"towers": {"rapid": {"damage": "10"}}}, {"enemies": {"basic": {"hp": true}}}, {"enemies": {"basic": {"unknown": 1}}}]:
		var candidate := before.duplicate(true)
		candidate.settings.developer_balance = invalid
		suite.check(not loaded.storage.valid_data(candidate), "Malformed balance settings are rejected at the storage boundary")
	loaded.reset_developer_balance("enemies", "basic")
	suite.check(not loaded.tuning.enemies.has("basic") and loaded.tuning.enemies.has("fast") and loaded.tuning.towers == before.settings.developer_balance.towers, "Reset selected preserves all other types")
	loaded.reset_developer_balance()
	suite.check(loaded.tuning.is_empty() and loaded.data.balance == before.balance and loaded.data.regions == before.regions, "Reset balance leaves progress intact")
	suite.check(loaded.save() and loaded.storage.read_candidate(loaded.save_path).settings.developer_balance.is_empty(), "Reset defaults persist")
	suite.clean_test_save(game.save_path)

static func test_live_enemies(suite: SceneTree) -> void:
	var game := VigilState.new(99)
	for kind in Balance.ENEMIES:
		var enemy: Dictionary = suite.fixture_enemy(game, kind)
		enemy.hp *= 0.5
		var position: Vector2 = enemy.pos
		game.set_balance_stat("enemies", kind, "hp", 300.0)
		suite.check(enemy.hp == 150.0 and enemy.max_hp == 300.0 and enemy.pos == position, "Live " + kind + " keeps damage fraction and position")
		game.set_balance_stat("enemies", kind, "speed", 100.0)
		game.data.regions["-1,0"].timer = 9.0
		game.combat.tick(Balance.STEP)
		suite.check(is_equal_approx(position.distance_to(enemy.pos), 5.0), "Live " + kind + " moves with adjusted speed")
		var spawned := game.combat.spawn("-1,0", kind)
		suite.check(spawned.hp == 300.0 and spawned.max_hp == 300.0, "New " + kind + " uses adjusted health")
		game.combat.enemies.clear()
	var tower := game.economy.build("rapid", "0,0", 0)
	var target: Dictionary = suite.fixture_enemy(game)
	game.economy.credit(tower, 12.5)
	game.data.regions["-1,0"].history = {tower: 999.0}
	game.data.regions["-1,0"].history_time = 60.0
	game.set_balance_stat("enemies", "basic", "payout", 42.0)
	suite.check(game.economy.unclaimed() == 12.5 and game.data.regions["-1,0"].history.is_empty(), "Balance changes preserve earnings and discard stale production estimates")
	suite.check(game.combat.hit(target, 1000.0, tower) and game.data.towers[tower].earnings == 54.5, "Adjusted enemy reward is credited on a live defeat")
	suite.check(not game.combat.hit(target, 1000.0, tower) and game.data.towers[tower].earnings == 54.5, "Adjusted rewards still pay once")
	var entry: Dictionary = preload("res://scripts/ui/info_catalog.gd").entries("enemies", game.tuning)[0]
	suite.check({"label": "Defeat reward", "value": "42 gold"} in entry.stats, "Guide displays the live enemy reward")

static func test_towers(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		var game := VigilState.new(43)
		game.data.balance = 10000.0
		game.set_balance_stat("towers", kind, "cost", 200.0)
		var before: float = game.data.balance
		var id := game.economy.build(kind, "0,0", 0)
		suite.check(game.data.balance == before - 200.0, "Adjusted build price is charged for " + kind)
		var tower: Dictionary = game.data.towers[id]
		var upgrade := Balance.upgrade_cost(tower, game.tuning)
		before = game.data.balance
		suite.check(game.economy.upgrade(id) and game.data.balance == before - upgrade, "Adjusted upgrade price is charged for " + kind)
		var refund := game.economy.sell(id)
		suite.check(refund.refund == floor((200.0 + upgrade) * Balance.SELL_REFUND_RATIO), "Adjusted refund agrees with prices for " + kind)
		id = game.economy.build(kind, "0,0", 0)
		tower = game.data.towers[id]
		var old_period: float = Balance.stats(kind, 1, game.tuning).period
		tower.cooldown = old_period * 0.5
		game.set_balance_stat("towers", kind, "period", 2.0)
		suite.check(is_equal_approx(tower.cooldown, 1.0), "Live cooldown preserves firing progress for " + kind)
		game.set_balance_stat("towers", kind, "damage", 10.0)
		game.set_balance_stat("towers", kind, "range", 600.0)
		game.set_balance_stat("towers", kind, "splash", 100.0)
		var first: Dictionary = suite.fixture_enemy(game)
		var second: Dictionary = suite.fixture_enemy(game)
		first.pos = Vector2(-200, 0)
		second.pos = Vector2(-195, 0)
		game.data.regions["-1,0"].timer = 9.0
		tower.cooldown = 0.0
		game.combat.tick(Balance.STEP)
		suite.check(first.hp == 5.0 and second.hp == 5.0 and tower.cooldown == 2.0, "Adjusted damage, range, blast and interval drive actual " + kind + " attacks")
		var custom := Balance.stats(kind, 2, game.tuning)
		var baseline := Balance.stats(kind, 2)
		suite.check(is_equal_approx(custom.damage / baseline.damage, 10.0 / Balance.TOWERS[kind].damage), "Upgraded damage scales from the custom base for " + kind)
		game.set_balance_stat("towers", kind, "splash", 0.0)
		suite.check(Balance.stats(kind, 2, game.tuning).splash == 0.0, "Zero blast disables splash at upgraded levels for " + kind)
		game.reset_developer_balance()
		suite.check(first.max_hp == Balance.ENEMIES.basic.hp and game.data.towers.has(id) and game.data.towers[id].level == 1, "Reset keeps built towers and live enemies")
