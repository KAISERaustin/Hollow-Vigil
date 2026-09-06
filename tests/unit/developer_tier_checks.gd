extends RefCounted

static func run(suite: SceneTree) -> void:
	for kind in Balance.TOWERS:
		var game: VigilState = suite.legacy_core_fixture(43)
		game.data.balance = 100000.0
		var defaults := {}
		for key in Balance.definitions("towers"):
			defaults[key] = Balance.definitions("towers")[key].duplicate()
		var tid := game.economy.build(kind, "0,0", 0)
		for stat in ["damage", "period", "range", "splash", "targets", "cost"]:
			var value: float = {"damage": 80.0, "period": 2.0, "range": 350.0, "splash": 20.0, "targets": 3.0, "cost": 17.0}[stat]
			suite.check(game.set_tower_tier_stat(kind, stat, value), "Tier 1 accepts independent " + stat)
			for level in range(2, 5):
				var branches: Array = Balance.BRANCHES[kind].keys() if level == 4 else [""]
				for branch in branches:
					var key := Balance.tier_key(kind, level, branch)
					var actual: float = Balance.stats(kind, level, game.tuning, branch)[stat]
					suite.check(is_equal_approx(actual, defaults[key][stat]), "Tier 1 edit preserves sibling " + key + "/" + stat)
		var tier2 := Balance.tier_key(kind, 2)
		suite.check(game.set_tower_tier_stat(tier2, "damage", 123.0), "Tier 2 damage editable")
		suite.check(game.set_tower_tier_stat(tier2, "cost", 23.0), "Tier 2 price editable")
		var before: float = game.data.balance
		suite.check(game.economy.upgrade(tid) and game.data.balance == before - 23.0, "Actual upgrade charges tier 2 price")
		suite.check(Balance.tower_stats(game.data.towers[tid], game.tuning).damage == 123.0, "Built tier 2 uses its damage")
		game.data.towers[tid].cooldown = Balance.tower_stats(game.data.towers[tid], game.tuning).period * 0.5
		game.set_tower_tier_stat(tier2, "period", 3.0)
		suite.check(game.data.towers[tid].cooldown == 1.5, "Tier cooldown progress preserved")
		game.set_tower_tier_stat(Balance.tier_key(kind, 3), "cost", 31.0)
		game.economy.upgrade(tid)
		var branches: Array = Balance.BRANCHES[kind].keys()
		for index in range(2):
			game.set_tower_tier_stat(Balance.tier_key(kind, 4, branches[index]), "cost", 41.0 + index * 20.0)
		before = game.data.balance
		suite.check(game.economy.upgrade(tid, 3, branches[1]) and game.data.balance == before - 61.0, "Right branch charges its own price")
		suite.check(Balance.invested_cost(game.data.towers[tid], game.tuning) == 132.0, "Refund investment uses chosen branch and all tier prices")
		game.set_tower_tier_stat(Balance.tier_key(kind, 4, branches[1]), "period", 120.0)
		game.data.towers[tid].cooldown = 60.0
		game.save_path = "user://developer-tiers.save"
		suite.clean_test_save(game.save_path)
		suite.check(game.save(), "Independent tiers save")
		var loaded := VigilState.new(44)
		loaded.save_path = game.save_path
		suite.check(loaded.load_save() and same_values(loaded.tuning, game.tuning), "Independent tiers reload")
		var before_reset := game.tuning.duplicate(true)
		game.reset_developer_balance("towers", tier2)
		before_reset.towers.erase(tier2)
		suite.check(game.tuning == before_reset, "Reset tier preserves siblings and other types")
		suite.clean_test_save(game.save_path)
	var guard := VigilState.new(55)
	for invalid in [{"rapid:9": {"damage": 2.0}}, {"rapid:doomstone": {"damage": 2.0}}, {"rapid:2": {"slow_duration": 2.0}}, {"electric:3": {"targets": 1.5}}]:
		suite.check(not guard.apply_balance({"towers": invalid}) and guard.tuning.is_empty(), "Malformed tier overrides are rejected atomically")
	test_abilities(suite)

static func test_abilities(suite: SceneTree) -> void:
	var fixtures = preload("res://tests/branch_runner.gd")
	# Use the existing branch fixtures through an instance without adding it to a tree.
	var helpers = fixtures.new()
	var game: VigilState = helpers.fixture("rapid", "frostneedle")
	var e: Dictionary = helpers.enemy(game)
	game.set_tower_tier_stat("rapid:frostneedle", "slow_percent", 60.0)
	game.set_tower_tier_stat("rapid:frostneedle", "slow_duration", 7.0)
	game.combat.branch_hit(helpers.shot(game, e), e)
	suite.check(e.slow_percent == 60.0 and e.slow_until == 7.0, "Frost strength and duration drive hits")
	var start: Vector2 = e.pos
	game.data.towers["1"].cooldown = 10.0
	game.combat.tick(0.05)
	suite.check(is_equal_approx(start.distance_to(e.pos), Balance.ENEMIES.basic.speed * 0.05 * 0.4), "Custom slow drives movement")
	game = helpers.fixture("splash", "rupture_pyre")
	e = helpers.enemy(game, Vector2.ZERO, "heavy")
	game.set_tower_tier_stat("splash:rupture_pyre", "push_distance", 80.0)
	game.set_tower_tier_stat("splash:rupture_pyre", "push_immunity", 4.0)
	game.set_balance_stat("enemies", "heavy", "push_resistance", 50.0)
	game.combat.branch_hit(helpers.shot(game, e), e)
	suite.check(e.pos.x == -40.0 and e.push_until == 4.0, "Knockback uses tower settings and enemy resistance")
	game = helpers.fixture("electric", "thunderseal")
	e = helpers.enemy(game)
	game.set_tower_tier_stat("electric:thunderseal", "seal_hits", 2.0)
	game.set_tower_tier_stat("electric:thunderseal", "seal_damage", 6.0)
	game.set_tower_tier_stat("electric:thunderseal", "stun_duration", 1.5)
	e.hp = 10000.0
	e.max_hp = e.hp
	for i in range(2):
		game.combat.branch_hit(helpers.shot(game, e), e)
	suite.check(e.hp == 10000.0 - 56.0 and e.stun_until == 1.5, "Custom seal threshold, damage, and stun affect combat")
	game = helpers.fixture("splash", "cinderfield")
	e = helpers.enemy(game)
	game.set_tower_tier_stat("splash:cinderfield", "burn_duration", 9.0)
	game.set_tower_tier_stat("splash:cinderfield", "burn_multiplier", 2.0)
	game.combat.ignite(helpers.shot(game, e))
	suite.check(game.combat.burning_ground[0].until == 9.0 and game.combat.burning_ground[0].damage == 54.0, "Custom burn duration and damage reach ground effects")
	game = helpers.fixture("heavy", "grave_echo")
	e = helpers.enemy(game)
	for index in range(3):
		helpers.enemy(game, Vector2(20 + index * 10, 0))
	game.set_tower_tier_stat("heavy:grave_echo", "fragment_count", 2.0)
	game.set_tower_tier_stat("heavy:grave_echo", "fragment_range", 35.0)
	game.set_tower_tier_stat("heavy:grave_echo", "fragment_multiplier", 0.5)
	game.combat.launch_fragments(helpers.shot(game, e))
	suite.check(game.combat.pending_shots.size() == 2 and is_equal_approx(game.combat.pending_shots[0].damage, 55.0), "Fragment count, range and damage apply")
	game = helpers.fixture("heavy", "doomstone")
	game.set_tower_tier_stat("heavy:doomstone", "curse_limit", 2.0)
	game.set_tower_tier_stat("heavy:doomstone", "curse_multiplier", 0.5)
	e = helpers.enemy(game)
	for index in range(4):
		game.combat.branch_hit(helpers.shot(game, e), e)
	suite.check(e.hp == 10000.0 - 585.0 and game.combat.curses["1"].stacks == 2, "Curse cap and multiplier drive repeated attacks")
	game = helpers.fixture("rapid", "thorn_volley")
	game.set_tower_tier_stat("rapid:thorn_volley", "arrow_count", 7.0)
	game.set_tower_tier_stat("rapid:thorn_volley", "fan_angle", 1.2)
	e = helpers.enemy(game, Vector2(100, 0))
	game.combat.launch_shot(game.data.towers["1"], Vector2.ZERO, e, Balance.tower_stats(game.data.towers["1"], game.tuning))
	suite.check(game.combat.pending_shots.size() == 7, "Custom volley emits the selected arrow count")
	game = helpers.fixture("electric", "tempest_web")
	game.set_tower_tier_stat("electric:tempest_web", "targets", 1.0)
	game.set_tower_tier_stat("electric:tempest_web", "arc_range", 100.0)
	game.set_tower_tier_stat("electric:tempest_web", "arc_multiplier", 2.0)
	var origin := VigilWorld.pad_position("0,0", 0)
	e = helpers.enemy(game, origin)
	var extra: Dictionary = helpers.enemy(game, origin + Vector2(80, 0))
	game.combat.tick(0.05)
	suite.check(e.hp == 9993.0 and extra.hp == 9986.0, "Single-target Tempest still applies custom chain reach and damage")
	var boss_fixtures = preload("res://tests/unit/boss_checks.gd")
	game = boss_fixtures.fixture("bell")
	game.set_balance_stat("bosses", "bell", "escort_kind", 5.0)
	game.combat.enemies[0].toll = 0.0
	game.combat.Bosses.advance(game.combat, 0.05)
	var escorts: Array = game.combat.enemies.filter(func(enemy): return enemy.has("summoner"))
	suite.check(escorts.size() == 3 and escorts[0].kind == "sentinel", "Bell can summon selected dungeon enemy")
	helpers.free()

# JSON numbers can differ in the final binary digit after parsing. Compare every
# key and numeric value, rather than requiring bit-identical float storage.
static func same_values(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
		if a[key] is Dictionary:
			if not b[key] is Dictionary or not same_values(a[key], b[key]):
				return false
		elif not is_equal_approx(float(a[key]), float(b[key])):
			return false
	return true
