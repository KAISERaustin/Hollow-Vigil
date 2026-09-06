extends RefCounted

static func run(suite: SceneTree) -> void:
	test_validation_and_storage(suite)
	test_live_enemies(suite)
	test_towers(suite)
	test_boss_tuning(suite)
	test_gear_tuning(suite)
	print("PASS GROUP: developer balance validation, persistence, live combat, pricing and resets")

static func test_validation_and_storage(suite: SceneTree) -> void:
	var game := VigilState.new(55)
	game.save_path = "user://developer-balance.save"
	suite.clean_test_save(game.save_path)
	suite.check(game.tuning.is_empty() and game.storage.valid_data(game.data), "Saves without developer settings use defaults")
	for category in Balance.TUNING_FIELDS:
		for kind in Balance.definitions(category):
			for stat in Balance.fields_for(category, kind):
				var limits: Dictionary = Balance.field_limits(category, kind, stat)
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
	var game: VigilState = suite.legacy_core_fixture(99)
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
		game.data.regions["-1,0"].style = "castle_ruin" if kind in Balance.DUNGEON_KINDS else "forest"
		var spawned: Dictionary = suite.fixture_enemy(game, kind)
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

static func test_towers(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		var game: VigilState = suite.legacy_core_fixture(43)
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
		suite.check(tower.cooldown == 2.0, "Adjusted interval drives actual " + kind + " attacks")
		suite.advance(game, 0.40)
		var expected_damage := 20.0 if kind == "electric" else 10.0
		suite.check(first.hp == Balance.ENEMIES.basic.hp - expected_damage and second.hp == Balance.ENEMIES.basic.hp - expected_damage, "Adjusted damage, range and blast apply at " + kind + " impact")
		var custom := Balance.stats(kind, 2, game.tuning)
		var baseline := Balance.stats(kind, 2)
		suite.check(is_equal_approx(custom.damage / baseline.damage, 10.0 / Balance.TOWERS[kind].damage), "Upgraded damage scales from the custom base for " + kind)
		game.set_balance_stat("towers", kind, "splash", 0.0)
		suite.check(Balance.stats(kind, 2, game.tuning).splash == 0.0, "Zero blast disables splash at upgraded levels for " + kind)
		game.reset_developer_balance()
		suite.check(first.max_hp == Balance.ENEMIES.basic.hp and game.data.towers.has(id) and game.data.towers[id].level == 1, "Reset keeps built towers and live enemies")

static func test_boss_tuning(suite: SceneTree) -> void:
	var bosses = preload("res://scripts/gameplay/encounters/bosses.gd")
	var fixtures = preload("res://tests/unit/boss_checks.gd")
	for kind in Balance.BOSSES:
		var game: VigilState = fixtures.fixture(kind)
		var e: Dictionary = game.combat.enemies[0]
		var position: Vector2 = e.pos
		e.hp *= 0.5
		game.set_balance_stat("bosses", kind, "hp", 10000.0)
		suite.check(e.hp == 5000.0 and e.max_hp == 10000.0 and e.pos == position, "Boss health tuning preserves damage fraction and position")
		game.set_balance_stat("bosses", kind, "speed", 80.0)
		suite.check(bosses.speed(e, 0.0, game.tuning) >= 80.0, "Boss movement uses tuned speed")
		for stat in Balance.fields_for("bosses", kind):
			game.set_balance_stat("bosses", kind, stat, Balance.TUNING_FIELDS.bosses[stat].max)
		suite.check(game.storage.valid_data(game.snapshot()), "Active boss with all maximum attributes is saveable")
		game.save_path = "user://developer-boss-" + kind + ".save"
		suite.clean_test_save(game.save_path)
		suite.check(game.save(), "Tuned active boss saves")
		var loaded := VigilState.new(44)
		loaded.save_path = game.save_path
		suite.check(loaded.load_save() and loaded.tuning == game.tuning, "Boss attributes survive reload")
		var restored: Array = loaded.combat.enemies.filter(func(enemy): return enemy.get("boss", false) and enemy.source == e.source)
		suite.check(restored.size() == 1 and restored[0].hp == e.hp and restored[0].max_hp == e.max_hp, "Boss reload retains tuned maximum and current health")
		for stat in Balance.fields_for("bosses", kind):
			game.set_balance_stat("bosses", kind, stat, Balance.TUNING_FIELDS.bosses[stat].min)
		suite.check(game.storage.valid_data(game.snapshot()), "Active boss at minimum attributes is saveable")
		game.reset_developer_balance("bosses", kind)
		suite.check(is_equal_approx(e.hp / e.max_hp, 0.5) and e.max_hp == Balance.BOSSES[kind].hp and game.storage.valid_data(game.snapshot()), "Reset restores boss defaults without healing and remains saveable")
		game.set_balance_stat("bosses", kind, "payout", 1234.0)
		var tid := game.economy.build("rapid", "0,0", 0)
		e.shield = 0.0
		e.wards = 0
		suite.check(game.combat.hit(e, 100000.0, tid) and game.data.towers[tid].earnings == 1234.0, "Boss defeat credits tuned gold")
		suite.check(not game.combat.hit(e, 100000.0, tid) and game.data.towers[tid].earnings == 1234.0, "Boss tuned reward pays once")
		suite.clean_test_save(game.save_path)
	var game: VigilState = fixtures.fixture("warden")
	var e: Dictionary = game.combat.enemies[0]
	game.set_balance_stat("bosses", "warden", "fire_multiplier", 4.0)
	bosses.damage(e, 100.0, "cinderfield", true, game.tuning)
	suite.check(e.shield == 200.0, "Cinderfield uses tuned shield damage multiplier")
	var tid := game.economy.build("splash", "0,0", 0)
	game.combat.burning_ground = [{"tower_id": tid, "pos": e.pos, "radius": 100.0, "until": 20.0}]
	game.set_balance_stat("bosses", "warden", "regrowth_suppression", 50.0)
	e.regen = 8.0
	bosses.advance(game.combat, 2.0)
	suite.check(e.regen == 7.0, "Partial Cinderfield suppression slows defense regrowth")
	game.set_balance_stat("bosses", "warden", "regrowth_suppression", 100.0)
	e.regen = 0.0
	e.shield = 0.0
	bosses.advance(game.combat, 0.05)
	suite.check(e.shield == 0.0, "Full suppression blocks even a ready regrowth timer")
	game = fixtures.fixture("cindermaw")
	e = game.combat.enemies[0]
	game.set_balance_stat("bosses", "cindermaw", "frost_multiplier", 3.0)
	game.set_balance_stat("bosses", "cindermaw", "armor_reduction", 20.0)
	suite.check(bosses.damage(e, 100.0, "frostneedle", false, game.tuning) == 240.0, "Frostneedle multiplier and armor reduction affect actual damage")
	e.hp = e.max_hp * 0.25
	e.slow_until = 10.0
	game.set_balance_stat("bosses", "cindermaw", "quench", 50.0)
	suite.check(is_equal_approx(bosses.speed(e, 0.0, game.tuning), 25.0 * 1.35), "Frostneedle partially suppresses haste at the tuned strength")
	game = fixtures.fixture("prior")
	e = game.combat.enemies[0]
	game.set_balance_stat("bosses", "prior", "doom_bypass", 0.0)
	suite.check(bosses.damage(e, 100.0, "doomstone", false, game.tuning) == 0.0 and e.wards == 2, "Disabling Doomstone bypass makes wards absorb its hit")
	game.set_balance_stat("bosses", "prior", "doom_bypass", 1.0)
	suite.check(bosses.damage(e, 100.0, "doomstone", false, game.tuning) == 100.0 and e.wards == 2, "Enabling Doomstone bypass preserves wards and damages boss")
	suite.check(not game.set_balance_stat("bosses", "prior", "wards", 2.5), "Fractional ward counts are rejected")
	suite.check(not game.set_balance_stat("bosses", "prior", "shield", 10.0), "Attributes belonging to other bosses are rejected")
	game = fixtures.fixture("bell")
	e = game.combat.enemies[0]
	tid = game.economy.build("electric", "0,0", 0)
	game.set_balance_stat("bosses", "bell", "seal_multiplier", 6.0)
	game.set_balance_stat("bosses", "bell", "toll_delay", 7.0)
	for i in range(5):
		game.combat.branch_hit({"tower_id": tid, "branch": "thunderseal", "damage": 10.0}, e)
	suite.check(e.hp == e.max_hp - 110.0 and e.toll == 15.0, "Thunderseal uses tuned detonation and delay")
	game.set_balance_stat("bosses", "bell", "escort_count", 2.0)
	game.set_balance_stat("bosses", "bell", "escort_limit", 3.0)
	game.set_balance_stat("bosses", "bell", "toll_period", 4.0)
	for i in range(2):
		e.toll = 0.01
		bosses.advance(game.combat, 0.05)
	var escorts := game.combat.enemies.filter(func(enemy): return enemy.get("summoner", -1) == e.id)
	suite.check(escorts.size() == 3 and e.toll == 4.0, "Bell honors tuned summon count, cap and interval")

static func test_gear_tuning(suite: SceneTree) -> void:
	const Relics = preload("res://scripts/gameplay/progression/relics.gd")
	for kind in Balance.GEAR:
		var game: VigilState = suite.legacy_core_fixture(879)
		var id := game.economy.build("rapid", "0,0", 0)
		var tower: Dictionary = game.data.towers[id]
		Relics.award(game.data, "90,90", kind)
		game.economy.equip_relic(id, "90,90", "")
		var enemy: Dictionary = suite.fixture_enemy(game)
		game.set_balance_stat("enemies", "basic", "hp", 10000.0)
		var stats := Balance.tower_stats(tower, game.tuning)
		match kind:
			"warden":
				game.set_balance_stat("gear", kind, "root_duration", 2.0)
				game.set_balance_stat("gear", kind, "boss_root_duration", 1.0)
				game.set_balance_stat("gear", kind, "root_immunity", 4.0)
				var attack := Relics.prepare(game.combat, tower, enemy, stats)
				game.combat.launch_shot(tower, enemy.pos, enemy, attack)
				game.combat.advance_shots(1.0)
				suite.check(enemy.root_until == 2.0 and enemy.root_immune_until == 4.0, "Equipped root gear uses edited duration and immunity on impact")
				game.combat.simulation_time = 3.0
				game.set_balance_stat("gear", kind, "root_period", 2.0)
				suite.check(game.combat.relic_progress[id].root_ready == 4.0, "Live root cooldown rescales its remaining half")
				var boss := {"id": -1, "boss": true}
				Relics.root_target(game.combat, {"relic_root": true, "target_id": -1}, boss)
				suite.check(boss.root_until == 4.0, "Gear has independent boss root duration")
			"cindermaw":
				game.set_balance_stat("gear", kind, "speed_per_stack", 50.0)
				game.set_balance_stat("gear", kind, "stack_limit", 2.0)
				game.set_balance_stat("gear", kind, "stack_timeout", 1.0)
				var attack := {}
				for index in range(4):
					attack = Relics.prepare(game.combat, tower, enemy, stats)
				suite.check(attack.period == stats.period / 2.0, "Equipped Fang uses tuned stack strength and cap")
				game.set_balance_stat("gear", kind, "stack_limit", 1.0)
				suite.check(game.combat.relic_progress[id].stacks == 1, "Reducing gear cap clamps existing stacks")
				game.combat.simulation_time = 1.0
				suite.check(Relics.prepare(game.combat, tower, enemy, stats).period == stats.period, "Tuned timeout clears existing attack speed stacks")
			"bell", "prior":
				game.set_balance_stat("gear", kind, "attack_count", 2.0)
				game.set_balance_stat("gear", kind, "echo_multiplier" if kind == "bell" else "damage_multiplier", 3.0)
				for index in range(2):
					game.combat.launch_shot(tower, enemy.pos, enemy, Relics.prepare(game.combat, tower, enemy, stats))
					game.combat.advance_shots(1.0)
				var expected: float = stats.damage * (5.0 if kind == "bell" else 4.0)
				suite.check(is_equal_approx(enemy.max_hp - enemy.hp, expected), "Equipped " + kind + " uses tuned activation count and actual damage")
		game.reset_developer_balance("gear", kind)
		suite.check(Balance.definition("gear", kind, game.tuning) == Balance.GEAR[kind], "Reset gear restores all of its effect defaults")
	var game: VigilState = preload("res://tests/unit/boss_checks.gd").fixture("warden")
	var boss: Dictionary = game.combat.enemies[0]
	var id := game.economy.build("rapid", "0,0", 0)
	var tower: Dictionary = game.data.towers[id]
	Relics.award(game.data, "90,90", "prior")
	game.economy.equip_relic(id, "90,90", "")
	game.set_balance_stat("gear", "prior", "attack_count", 1.0)
	game.set_balance_stat("gear", "prior", "damage_multiplier", 2.0)
	for bypass in [0.0, 1.0]:
		game.set_balance_stat("gear", "prior", "defense_bypass", bypass)
		var before: float = boss.hp
		var stats := Balance.tower_stats(tower, game.tuning)
		game.combat.launch_shot(tower, boss.pos, boss, Relics.prepare(game.combat, tower, boss, stats))
		game.combat.advance_shots(1.0)
		suite.check(boss.hp == before - stats.damage * 2.0 * bypass, "Gear defense bypass toggle controls real boss shield penetration")
