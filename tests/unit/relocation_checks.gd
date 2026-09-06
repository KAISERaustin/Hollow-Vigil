extends RefCounted

static func run(suite: SceneTree) -> void:
	test_transactions(suite)
	test_rebuild_combat(suite)
	test_saved_timers(suite)
	print("PASS GROUP: tower relocation costs, rebuild combat, destination guards, saved timers and offline safety")

static func test_transactions(suite: SceneTree) -> void:
	var g := VigilState.new(780)
	g.data.balance = 10000.0
	g.expand("1,0")
	var id := g.economy.build("rapid", "0,0", 0)
	var other := g.economy.build("heavy", "1,0", 1)
	for kind in Balance.TOWERS:
		var tower := {"kind": kind, "level": 1}
		suite.check(Balance.move_cost(tower) == {"rapid": 12.0, "splash": 24.0, "heavy": 32.0, "electric": 28.0}[kind], "Base move price for " + kind)
		suite.check(Balance.rebuild_seconds(tower) == {"rapid": 30.0, "splash": 60.0, "heavy": 80.0, "electric": 70.0}[kind], "Distinct base rebuild timer for " + kind)
		var previous_cost := Balance.move_cost(tower)
		var previous_time := Balance.rebuild_seconds(tower)
		for level in range(2, Balance.MAX_TOWER_LEVEL + 1):
			tower.level = level
			suite.check(Balance.move_cost(tower) > previous_cost and Balance.rebuild_seconds(tower) > previous_time, "Upgraded towers cost more and take longer to relocate")
			previous_cost = Balance.move_cost(tower)
			previous_time = Balance.rebuild_seconds(tower)
		var tuning := {"towers": {kind: {"cost": 1000.0}}}
		suite.check(Balance.rebuild_seconds(tower, tuning) == 180.0, "Even developer prices cannot exceed a three-minute rebuild")
	g.economy.upgrade(id)
	g.economy.credit(id, 17.5)
	for region in g.data.regions.values():
		region.history = {id: 50.0, other: 25.0}
		region.history_time = 60.0
	var before := g.data.duplicate(true)
	for target in [["missing", "0,0", 2, 2], [id, "2,0", 0, 2], [id, "0,0", -1, 2], [id, "0,0", 4, 2], [id, "0,0", 0, 2], [id, "1,0", 1, 2], [id, "1,0", 2, 1]]:
		suite.check(not g.economy.relocate(target[0], target[1], target[2], target[3]) and g.data == before, "Invalid or stale relocation has no side effects: " + str(target))
	g.data.balance = Balance.move_cost(g.data.towers[id]) - 0.5
	var poor := g.data.duplicate(true)
	suite.check(not g.economy.relocate(id, "1,0", 2, 2) and g.data == poor, "Insufficient gold cannot start a rebuild")
	g.data.balance = before.balance
	var refund := Balance.sell_refund(g.data.towers[id])
	suite.check(g.economy.relocate(id, "1,0", 2, 2), "Tower relocates into another owned territory")
	var tower: Dictionary = g.data.towers[id]
	suite.check(g.data.balance == before.balance - 24.0 and tower.rebuild_remaining == 45.0, "Level-two Ashneedle charges 24 gold and starts 45 seconds")
	suite.check(tower.id == id and tower.level == 2 and tower.earnings == 17.5 and g.data.next_tower == before.next_tower, "Relocation retains identity, upgrades and every earned fraction")
	suite.check(g.economy.tower_at("0,0", 0) == "" and g.economy.tower_at("1,0", 2) == id, "Relocation releases the original socket and reserves the destination")
	suite.check(g.data.towers[other] == before.towers[other] and Balance.sell_refund(tower) == refund, "Moving leaves other towers intact and never adds its fee to sale value")
	for region in g.data.regions.values():
		suite.check(not region.history.has(id) and region.history[other] == 25.0, "Only the moved tower loses its old production history")
	var rebuilding := g.data.duplicate(true)
	suite.check(not g.economy.relocate(id, "0,0", 3, 2) and not g.economy.upgrade(id, 2) and g.data == rebuilding, "Rebuilding towers cannot move again or upgrade")
	suite.check(g.economy.build("rapid", "0,0", 0) != "" and g.economy.build("rapid", "1,0", 2) == "", "Building respects both vacated and rebuilding sockets")
	suite.check(g.storage.valid_data(g.data), "Relocation produces a valid save")
	var sale := g.economy.sell(id, 2)
	suite.check(sale.total == refund + 17.5 and not g.data.towers.has(id), "A rebuilding tower can still be sold once for its normal refund")

static func test_rebuild_combat(suite: SceneTree) -> void:
	var g: VigilState = suite.legacy_core_fixture(781)
	g.data.balance = 10000.0
	var id := g.economy.build("rapid", "0,0", 0)
	g.economy.relocate(id, "0,0", 1)
	var enemy: Dictionary = suite.fixture_enemy(g)
	enemy.pos = VigilWorld.pad_position("0,0", 1) + Vector2(15, 0)
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	g.combat.tick(Balance.STEP)
	suite.check(enemy.hp == 1000.0 and is_equal_approx(g.data.towers[id].rebuild_remaining, 29.95), "Rebuilding advances without firing at an in-range target")
	g.data.towers[id].rebuild_remaining = Balance.STEP
	g.combat.tick(Balance.STEP)
	suite.check(enemy.hp == 1000.0 and g.data.towers[id].rebuild_remaining == 0.0, "Final construction tick cannot fire early")
	g.combat.tick(Balance.STEP)
	suite.check(not g.combat.pending_shots.is_empty(), "Completed tower resumes firing from the new position")
	suite.check(g.economy.upgrade(id, 1), "Upgrades unlock after construction completes")

static func test_saved_timers(suite: SceneTree) -> void:
	var g: VigilState = suite.legacy_core_fixture(782)
	g.save_path = "user://relocation-test.save"
	suite.clean_test_save(g.save_path)
	g.data.balance = 10000.0
	var id := g.economy.build("rapid", "0,0", 0)
	g.data.regions["0,0"].history = {id: 60.0}
	g.data.regions["0,0"].history_time = 60.0
	g.economy.credit(id, 19.5)
	g.economy.relocate(id, "0,0", 2)
	g.data.last_accounted = 1000.0
	suite.check(g.save(1000.0), "An active rebuild can be saved")
	var loaded := VigilState.new()
	loaded.save_path = g.save_path
	suite.check(loaded.load_save(1010.0), "Rebuilding save reloads")
	suite.check(loaded.data.towers[id].pad == 2 and loaded.data.towers[id].rebuild_remaining == 20.0 and loaded.data.towers[id].earnings == 19.5, "Reload preserves destination and earnings while subtracting time away")
	suite.check(loaded.load_save(1010.0) and loaded.data.towers[id].rebuild_remaining == 20.0, "Repeated reload cannot advance construction twice")
	loaded.apply_offline(900.0)
	suite.check(loaded.data.towers[id].rebuild_remaining == 20.0, "Backward clock cannot extend or finish construction")
	loaded.apply_offline(1010.5)
	suite.check(loaded.data.towers[id].rebuild_remaining == 19.5, "Sub-two-second offline intervals still advance rebuilds")
	suite.check(loaded.apply_offline(1040.0) == 0.0 and loaded.data.towers[id].rebuild_remaining == 0.0, "Time away finishes construction without retaining old-location income")
	suite.check(loaded.save(1040.0) and loaded.load_save(1040.0) and loaded.data.towers[id].rebuild_remaining == 0.0, "Finished construction stays finished after reopening")
	var legacy := g.data.duplicate(true)
	legacy.sequence = loaded.data.sequence + 10
	legacy.towers[id].erase("rebuild_remaining")
	suite.check(g.storage.write(g.save_path, legacy) and loaded.load_save(1000.0) and loaded.data.towers[id].rebuild_remaining == 0.0, "Saves without the optional rebuild field load ready to fire")
	for invalid in [-1.0, 181.0, INF, NAN, "30"]:
		var bad := g.data.duplicate(true)
		bad.towers[id].rebuild_remaining = invalid
		suite.check(not g.storage.valid_data(bad), "Malformed saved rebuild timer rejected")
	suite.clean_test_save(g.save_path)
