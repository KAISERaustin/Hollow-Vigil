extends RefCounted

const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const BossChecks = preload("res://tests/unit/boss_checks.gd")

static func run(suite: SceneTree) -> void:
	for kind in Balance.BOSSES:
		var game := BossChecks.fixture(kind)
		var boss: Dictionary = game.combat.enemies[0]
		var id := game.economy.build("heavy", "0,0", 0)
		game.combat.hit(boss, 1.0e6, id, "", false, true)
		game.combat.hit(boss, 1.0e6, id, "", false, true)
		var expected := {}
		for gear_kind in Relics.BOSS_DROPS[kind]:
			expected[Relics.drop_id(boss.source, gear_kind, kind)] = gear_kind
		suite.check(game.data.relics == expected and game.combat.relic_drops.size() == 3, "Boss grants exactly three identity-bound relics once: " + kind)
		suite.check(boss.source in Relics.available(game.data), "Newly awarded equipment is available")
		suite.check(game.economy.equip_relic(id, boss.source, ""), "Every boss drop can be equipped")
		suite.check(boss.source not in Relics.available(game.data), "Equipped equipment is excluded")
		var second := game.economy.build("rapid", "0,0", 1)
		game.data.regions[boss.source].history[id] = 100.0
		game.combat.relic_progress[id] = {"attacks": 3}
		suite.check(not game.economy.equip_relic(second, boss.source, "", ""), "Stale owner cannot transfer an equipped relic")
		suite.check(game.economy.equip_relic(second, boss.source, "", id), "Explicit transfer succeeds")
		suite.check(not game.data.towers[id].has("relic") and not game.combat.relic_progress.has(id) and not game.data.regions[boss.source].history.has(id), "Transfer releases old slot, charges and demonstrated income")
		suite.check(boss.source not in Relics.available(game.data), "Transferred equipment remains unavailable")
		var snapshot := game.snapshot(1000)
		suite.check(game.storage.valid_data(snapshot), "Equipped relic snapshot validates")
		var broken := snapshot.duplicate(true)
		broken.towers[id].relic = boss.source
		suite.check(not game.storage.valid_data(broken), "Two towers cannot own the same saved relic")
		broken = snapshot.duplicate(true)
		broken.relics[boss.source] = "unknown"
		suite.check(not game.storage.valid_data(broken), "Unknown relic kinds fail save validation")
		broken = snapshot.duplicate(true)
		broken.towers[id].relic = "999,999"
		suite.check(not game.storage.valid_data(broken), "Unowned equipment fails save validation")
		game.save_path = "user://relic-roundtrip.save"
		suite.clean_test_save(game.save_path)
		suite.check(game.save(1000), "Equipment saved")
		var restored := VigilState.new()
		restored.save_path = game.save_path
		suite.check(restored.load_save(1001) and restored.data.relics == game.data.relics and restored.data.towers[second].relic == boss.source, "Inventory and ownership survive reload")
		suite.check(restored.economy.upgrade(second) and restored.data.towers[second].relic == boss.source, "Upgrade retains equipment")
		suite.check(restored.economy.relocate(second, "0,0", 2) and restored.data.towers[second].relic == boss.source, "Relocation retains equipment")
		suite.check(boss.source not in Relics.available(restored.data), "Saved equipped ownership controls availability")
		restored.economy.sell(second)
		suite.check(boss.source in Relics.available(restored.data), "Selling the owner makes equipment available")
		suite.check(restored.data.relics.has(boss.source) and Relics.owner(restored.data, boss.source) == "", "Selling returns equipment to collection")
		game.data.erase("relics")
		game.data.towers[second].erase("relic")
		suite.check(game.save(1002) and restored.load_save(1003), "Pre-equipment save migrates")
		suite.check(restored.data.relics == expected, "Old victory receives its missing three-piece set")
		var escaped := game.data.duplicate(true)
		escaped.regions[boss.source].boss.status = "escaped"
		Relics.migrate(escaped)
		suite.check(escaped.relics.is_empty(), "Legacy escapes do not receive equipment")
		Relics.migrate(restored.data)
		suite.check(restored.data.relics.size() == 3, "Migration cannot duplicate drops")
		suite.clean_test_save(game.save_path)
	combat_checks(suite)
	var movement_game := suite.legacy_core_fixture(879) as VigilState
	var walker := suite.fixture_enemy(movement_game) as Dictionary
	walker.root_until = 0.5
	var before: Vector2 = walker.pos
	movement_game.combat.tick(0.05)
	suite.check(walker.pos == before, "Root stops movement in the simulation")
	movement_game.combat.tick(0.5)
	suite.check(walker.pos != before, "Movement resumes after root expires")


static func combat_checks(suite: SceneTree) -> void:
	# Exercise every base tower and all eight specialization launch paths.
	for tower_kind in Balance.TOWERS:
		var branches: Array = [""] + Balance.BRANCHES[tower_kind].keys()
		for branch in branches:
			for relic_kind in Relics.DEFINITIONS:
				var game := suite.legacy_core_fixture(879) as VigilState
				game.data.balance = 100000.0
				var id := game.economy.build(tower_kind, "0,0", 0)
				var tower: Dictionary = game.data.towers[id]
				if branch != "":
					tower.level = 4
					tower.branch = branch
				Relics.award(game.data, "90,90", relic_kind)
				game.economy.equip_relic(id, "90,90", "")
				var enemy := suite.fixture_enemy(game) as Dictionary
				enemy.hp = 100000.0
				enemy.max_hp = enemy.hp
				enemy.pos = VigilWorld.pad_position("0,0", 0) + Vector2(0, -60)
				var stats := Balance.tower_stats(tower)
				var last := {}
				for attack in range(1, 7):
					last = Relics.prepare(game.combat, tower, enemy, stats)
					game.combat.launch_shot(tower, VigilWorld.pad_position("0,0", 0), enemy, last)
					game.combat.advance_shots(1.0)
					game.combat.simulation_time += 0.5
				var context: String = tower_kind + "/" + branch + "/" + relic_kind
				suite.check(enemy.hp < enemy.max_hp and game.combat.relic_progress[id].attacks == 6, "Relic supports launch path " + context)
				if relic_kind == "warden":
					suite.check(is_equal_approx(enemy.get("root_until", 0.0), 0.75), "Root applies once per six-second cooldown: " + context)
				if relic_kind == "cindermaw":
					suite.check(is_equal_approx(last.period, stats.period / 1.4), "Ember Fang reaches capped attack speed: " + context)
					game.combat.simulation_time += 3.0
					suite.check(Relics.prepare(game.combat, tower, enemy, stats).period == stats.period, "Idle time resets Ember Fang")
					var other := enemy.duplicate(true)
					other.id += 1
					suite.check(Relics.prepare(game.combat, tower, other, stats).period == stats.period, "Target change resets Ember Fang")
	# Quantify damage independently of specialization effects and secondary targets.
	for kind in ["bell", "prior"]:
		var game := suite.legacy_core_fixture(879) as VigilState
		game.data.balance = 100000.0
		var id := game.economy.build("electric", "0,0", 0)
		var tower: Dictionary = game.data.towers[id]
		Relics.award(game.data, "90,90", kind)
		game.economy.equip_relic(id, "90,90", "")
		var enemy := suite.fixture_enemy(game) as Dictionary
		enemy.hp = 1000.0
		var stats := Balance.tower_stats(tower)
		var count := 4 if kind == "bell" else 5
		for index in range(count):
			game.combat.launch_shot(tower, Vector2.ZERO, enemy, Relics.prepare(game.combat, tower, enemy, stats))
			game.combat.advance_shots(1.0)
		suite.check(is_equal_approx(1000.0 - enemy.hp, stats.damage * (count + 0.5)), "One extra half-strength hit per cadence: " + kind)
		game.economy.equip_relic(id, "", "90,90")
		suite.check(game.combat.relic_progress.is_empty(), "Unequipping clears attack charges")
	for kind in ["warden", "prior", "cindermaw"]:
		var game := BossChecks.fixture(kind)
		var boss: Dictionary = game.combat.enemies[0]
		var id := game.economy.build("rapid", "0,0", 0)
		var health: float = boss.hp
		game.combat.branch_hit({"tower_id": id, "damage": 100.0, "relic_pierce": true}, boss)
		suite.check(boss.hp == health - 100.0, "Eclipse pierces " + kind + " defenses")
		if kind == "cindermaw":
			game.combat.branch_hit({"tower_id": id, "damage": 100.0, "branch": "frostneedle", "relic_pierce": true}, boss)
			suite.check(boss.hp == health - 250.0, "Piercing retains Frostneedle's boss weakness bonus")
		Relics.root_target(game.combat, {"target_id": boss.id, "relic_root": true}, boss)
		suite.check(boss.root_until == 0.35, "Boss root has reduced duration")
		game.combat.simulation_time = 1.0
		Relics.root_target(game.combat, {"target_id": boss.id, "relic_root": true}, boss)
		suite.check(boss.root_until == 0.35, "Shared immunity prevents root chains")
