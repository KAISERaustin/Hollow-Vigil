extends RefCounted

static func run(suite: SceneTree) -> void:
	test_offline(suite)
	test_storage(suite)
	test_reset_progress(suite)
	test_invalid_snapshots(suite)

static func test_offline(suite: SceneTree) -> void:
	var g := VigilState.new(2)
	g.economy.build("rapid", "0,0", 0)
	g.data.last_accounted = 1000
	suite.check(g.apply_offline(4600) == 0, "New-save offline fallback is zero until demonstrated kills")
	g.data.regions["0,0"].history = {"1": 120.0}
	g.data.regions["0,0"].history_time = 120.0
	g.data.last_accounted = 1000
	suite.check(is_equal_approx(g.apply_offline(4600), 2880), "Offline income is 80 percent of demonstrated production")
	var total := g.economy.unclaimed()
	suite.check(g.apply_offline(4600) == 0 and g.economy.unclaimed() == total, "Same interval cannot reward twice")
	suite.check(g.apply_offline(100) == 0 and g.data.last_accounted == 4600, "Backward clock does not reset watermark")
	suite.check(g.apply_offline(4600) == 0, "Returning clock to prior time cannot replay reward")
	suite.check(g.data.kills == 0, "Estimated offline kills do not inflate lifetime actual kills")
	var reward := g.apply_offline(1.0e12)
	suite.check(is_equal_approx(reward, 0.8 * Balance.MAX_OFFLINE_SECONDS), "Huge forward jump uses seven-day guard")
	suite.check(g.data.towers.size() == 1 and g.data.regions.size() == 1 and g.data.towers["1"].level == 1, "Offline processing never builds, expands, or upgrades")
	var abandoned := VigilState.new(2)
	abandoned.data.towers.clear()
	suite.advance(abandoned, 120)
	abandoned.data.last_accounted = 1000
	suite.check(abandoned.apply_offline(4600) == 0, "Escaped traffic produces no offline earnings")
	print("PASS GROUP: offline interval and clock integrity")

static func test_storage(suite: SceneTree) -> void:
	var path := "user://integrity-test.save"
	suite.clean_test_save(path)
	var g := VigilState.new(7654)
	g.economy.build("rapid", "0,0", 0)
	g.save_path = path
	g.data.last_accounted = 1000
	g.data.balance = 500
	g.data.settings.text_scale = 1.5
	g.data.settings.reduced_motion = true
	g.expand("0,-1")
	g.economy.build("heavy", "0,-1", 2)
	g.economy.credit("1", 25)
	g.data.regions["0,0"].history = {"1": 60.0}
	g.data.regions["0,0"].history_time = 60.0
	suite.check(g.save(1000), "Save writes a verified snapshot")
	var loaded := VigilState.new()
	loaded.save_path = path
	suite.check(loaded.load_save(1060), "Snapshot loads")
	suite.check(loaded.data.settings.text_scale == 1.5 and loaded.data.settings.reduced_motion, "UI preferences survive save and reload")
	suite.check(loaded.data.seed == 7654 and loaded.data.regions.size() == 2 and loaded.data.towers.size() == 2, "Seed, region, and towers survive loading")
	suite.check(loaded.paths == g.paths, "Discovered roads remain identical after loading")
	suite.check(loaded.paths["0,0"].back() == Vector2.ZERO and loaded.paths["0,-1"].back() == Vector2.ZERO, "Existing save topology reconstructs routes to the central core")
	suite.check(is_equal_approx(loaded.economy.unclaimed(), 73), "Loaded offline reward is added exactly once")
	var again := VigilState.new()
	again.save_path = path
	suite.check(again.load_save(1060) and is_equal_approx(again.economy.unclaimed(), 73), "Immediate reopening cannot repeat offline reward")
	# Simulate interruption after validated temporary write, before primary rename.
	var candidate: Dictionary = again.data.duplicate(true)
	candidate.sequence += 10
	candidate.balance = 1234
	var text := JSON.stringify(candidate)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": text, "checksum": text.sha256_text()}))
	file.close()
	var interrupted := VigilState.new()
	interrupted.save_path = path
	suite.check(interrupted.load_save(1060) and interrupted.data.balance == 1234, "Valid newer temporary snapshot recovers interrupted promotion")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string("{also-truncated")
	file.close()
	var recovered := VigilState.new()
	recovered.save_path = path
	suite.check(recovered.load_save(1060), "Corrupt primary and temporary files recover backup")
	suite.check(not recovered.storage.read_candidate(path).is_empty(), "Recovery promotes a valid new primary")
	suite.check(recovered.economy.build("rapid", "0,0", 3) != "", "Loaded integer tower IDs permit further purchases")
	suite.clean_test_save(path)
	print("PASS GROUP: saves, atomic rewards, interrupted writes")

static func test_reset_progress(suite: SceneTree) -> void:
	var g := VigilState.new(123)
	g.save_path = "user://reset-progress-test.save"
	suite.clean_test_save(g.save_path)
	g.data.balance = 1.0e9
	g.expand("1,0")
	g.economy.build("heavy", "1,0", 1)
	g.economy.upgrade("1", 1)
	g.economy.unlock("0,0", "fast")
	g.economy.buy_traffic("0,0")
	g.data.automation = true
	g.data.camera = [100.0, 200.0, 0.5]
	suite.advance(g, 30)
	g.offline_award = 100.0
	suite.check(g.save() and g.save(), "Progress exists in primary and backup before reset")
	suite.check(g.reset_progress(), "Reset commits a fresh game")
	var fresh := VigilState.new(int(g.data.seed))
	for key in fresh.data:
		if key not in ["sequence", "last_accounted"]:
			suite.check(g.data[key] == fresh.data[key], "Reset restores starting value: " + key)
	suite.check(g.combat.enemies.is_empty() and g.offline_award == 0.0, "Reset clears live enemies and offline award")
	suite.check(g.paths.size() == 1, "Reset clears expanded routes")
	var loaded := VigilState.new()
	loaded.save_path = g.save_path
	suite.check(loaded.load_save(), "Reset persists after reopening")
	suite.check(loaded.data.regions.size() == 1 and loaded.data.towers.is_empty() and not loaded.data.automation, "Reopening cannot restore purchases")
	var backup := g.storage.read_candidate(g.save_path + ".bak")
	suite.check(backup.regions.size() == 1 and backup.towers.is_empty() and backup.balance == Balance.STARTING_GOLD, "Recovery backup also contains fresh progress")
	g.save_path = "user://missing-reset-directory/test.save"
	var before := g.data.duplicate(true)
	suite.check(not g.reset_progress() and g.data == before, "Failed reset save leaves current game intact")
	suite.clean_test_save(loaded.save_path)
	print("PASS GROUP: progress reset and recovery persistence")

static func test_invalid_snapshots(suite: SceneTree) -> void:
	var g := VigilState.new(22)
	g.economy.build("rapid", "0,0", 0)
	var store := VigilSaveStore.new()
	suite.check(store.valid_data(g.data), "New state passes complete save schema")
	var d: Dictionary = g.data.duplicate(true)
	d.camera = []
	suite.check(not store.valid_data(d), "Incomplete camera rejected")
	d = g.data.duplicate(true)
	d.settings.low_power = "yes"
	suite.check(not store.valid_data(d), "Malformed settings rejected")
	for invalid_scale in [0.0, 1.2, 5.0, NAN, "large"]:
		d = g.data.duplicate(true)
		d.settings.text_scale = invalid_scale
		suite.check(not store.valid_data(d), "Invalid UI text scale rejected")
	d = g.data.duplicate(true)
	d.settings.reduced_motion = "yes"
	suite.check(not store.valid_data(d), "Invalid reduced-motion setting rejected")
	d = g.data.duplicate(true)
	d.balance = NAN
	suite.check(not store.valid_data(d), "Nonfinite currency rejected")
	d = g.data.duplicate(true)
	d.towers["1"].level = 1.5
	suite.check(not store.valid_data(d), "Fractional tower level rejected")
	d = g.data.duplicate(true)
	d.regions["0,0"].history = {"missing": 100}
	suite.check(not store.valid_data(d), "Unknown historical tower rejected")
	d = g.data.duplicate(true)
	d.regions["0,0"].history = {"1": INF}
	suite.check(not store.valid_data(d), "Infinite production history rejected")
	d = g.data.duplicate(true)
	d.towers["2"] = d.towers["1"].duplicate(true)
	d.towers["2"].id = "2"
	d.next_tower = 3
	suite.check(not store.valid_data(d), "Overlapping saved tower placements rejected")
	d = g.data.duplicate(true)
	d.regions["bad-coordinate"] = d.regions["0,0"].duplicate(true)
	d.regions["0,0"].parent = "bad-coordinate"
	suite.check(not store.valid_data(d), "Malformed parent coordinates rejected before traversal")
	g.data.balance = 10000
	g.expand("1,0")
	g.expand("2,0")
	d = g.data.duplicate(true)
	d.regions["1,0"].parent = "2,0"
	d.regions["2,0"].parent = "1,0"
	suite.check(not store.valid_data(d), "Cyclic saved parent graph rejected")
	suite.check(g.apply_offline(NAN) == 0 and g.apply_offline(INF) == 0, "Nonfinite clocks cannot generate rewards")
	print("PASS GROUP: malformed save schema and numeric guards")
