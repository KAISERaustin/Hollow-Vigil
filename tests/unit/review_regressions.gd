extends RefCounted

static func run(suite: SceneTree) -> void:
	combat_guards(suite)
	content_contract(suite)
	storage_guards(suite)
	var tile := VigilTerrainTile.new()
	var region := VigilWorld.make_region("0,0", "", 79)
	tile.configure(region, 79)
	var roads := tile.roads.duplicate(true)
	var scenery := tile.scenery.duplicate(true)
	tile.configure(region, 79)
	suite.check(tile.roads == roads and tile.scenery == scenery, "Reconfiguring a tile cannot duplicate roads or props")
	tile.free()
	print("PASS GROUP: review regressions for combat guards, content contracts, save preservation, and reusable terrain")

static func combat_guards(suite: SceneTree) -> void:
	var game: VigilState = suite.legacy_core_fixture(79)
	var tower := game.economy.build("rapid", "0,0", 0)
	var enemy: Dictionary = suite.fixture_enemy(game)
	var health: float = enemy.hp
	for damage in [NAN, INF, -10.0, 0.0]:
		suite.check(not game.combat.hit(enemy, damage, tower), "Invalid damage cannot defeat an enemy")
	suite.check(not game.combat.hit(enemy, 1000.0, "missing"), "Missing tower cannot leave invalid production history")
	suite.check(enemy.hp == health and game.data.kills == 0 and game.economy.unclaimed() == 0, "Rejected hits leave health and earnings unchanged")
	var serial := game.combat.enemy_serial
	suite.check(game.combat.spawn("-1,0", "missing").is_empty() and game.combat.enemy_serial == serial, "Unknown enemy cannot partially spawn")
	var before := game.data.duplicate(true)
	for delta in [NAN, INF, -0.5, 0.0]:
		game.combat.tick(delta)
	suite.check(game.data == before and game.combat.simulation_time == 0, "Invalid tick intervals cannot mutate simulation")
	game.data.balance = Balance.MAX_MONEY
	game.data.towers[tower].level = Balance.MAX_TOWER_LEVEL
	before = game.data.duplicate(true)
	suite.check(not game.economy.upgrade(tower) and game.data == before, "Shared level limit blocks spending")

static func content_contract(suite: SceneTree) -> void:
	var shares := 0.0
	for kind in Balance.ENEMY_SHARES:
		suite.check(Balance.ENEMIES.has(kind) and Balance.UNLOCK_COSTS.has(kind), "Spawn shares reference a purchasable enemy")
		suite.check(Balance.ENEMY_SHARES[kind] > 0.0 and Balance.UNLOCK_COSTS[kind] > 0.0, "Shares and costs are positive")
		shares += Balance.ENEMY_SHARES[kind]
	suite.check(shares < 1.0, "Unlocked shares leave room for basic enemies")
	for kind in Balance.UNLOCK_COSTS:
		suite.check(Balance.ENEMIES.has(kind) and Balance.ENEMY_SHARES.has(kind), "Every unlock has a definition and share")
	for kind in Balance.ENEMIES:
		var enemy: Dictionary = Balance.ENEMIES[kind]
		suite.check(enemy.hp > 0 and enemy.speed > 0 and enemy.payout >= 0, "Enemy stats support movement and rewards")
	for kind in Balance.TOWERS:
		var tower := Balance.stats(kind, 1)
		suite.check(tower.cost > 0 and tower.damage > 0 and tower.period > 0 and tower.range > 0 and tower.splash >= 0, "Tower stats support purchases and targeting")
	suite.check(Balance.enemy_mix([]) == {"basic": 1.0}, "Locked enemies never appear in the spawn mix")
	for unlocks in [["fast"], ["heavy"], ["fast", "heavy"]]:
		var mix := Balance.enemy_mix(unlocks)
		var total := 0.0
		for kind in mix:
			suite.check(Balance.enemy_kind(unlocks, total + mix[kind] * 0.5) == kind, "Spawner uses the share shown by the rift panel")
			total += mix[kind]
		suite.check(is_equal_approx(total, 1.0), "Each spawn mix totals 100 percent")
	for style in VigilWorld.STYLES:
		suite.check(VigilTerrainArt.BIOME_COLORS.has(style), "Every saved biome has artwork")

static func storage_guards(suite: SceneTree) -> void:
	var path := "user://review-regression.save"
	suite.clean_test_save(path)
	var game: VigilState = suite.legacy_core_fixture(79)
	game.save_path = path
	game.data.last_accounted = 1000.0
	game.economy.build("rapid", "0,0", 0)
	suite.check(game.save(1000.0), "Regression fixture writes a valid save")
	var candidate := game.data.duplicate(true)
	candidate.sequence += 5
	write_candidate(path + ".tmp", candidate)
	var interrupted := FileAccess.get_file_as_string(path + ".tmp")
	var invalid := game.data.duplicate(true)
	invalid.balance = NAN
	suite.check(not game.storage.write(path, invalid), "Invalid snapshot is rejected before touching recovery files")
	suite.check(FileAccess.get_file_as_string(path + ".tmp") == interrupted, "Invalid write preserves newer temporary recovery snapshot")
	for id in ["0", "-1", "01", "+1"]:
		invalid = game.data.duplicate(true)
		var tower: Dictionary = invalid.towers["1"]
		invalid.towers.erase("1")
		tower.id = id
		invalid.towers[id] = tower
		suite.check(not game.storage.valid_data(invalid), "Noncanonical tower ID is rejected: " + id)
	invalid = game.data.duplicate(true)
	invalid.regions["0,0"].unlocks = ["fast", "fast"]
	suite.check(not game.storage.valid_data(invalid), "Duplicate saved unlocks are rejected")
	for suffix in ["", ".tmp", ".bak"]:
		FileAccess.open(path + suffix, FileAccess.WRITE).store_string("unreadable progress")
	var loaded := VigilState.new(80)
	loaded.save_path = path
	suite.check(not loaded.load_save(1000.0) and loaded.save_blocked and not loaded.save_error.is_empty(), "Unreadable saves are reported and protected")
	suite.check(not loaded.save(1000.0), "Autosave cannot overwrite unreadable progress")
	for suffix in ["", ".tmp", ".bak"]:
		suite.check(FileAccess.get_file_as_string(path + suffix) == "unreadable progress", "Rejected autosave preserves " + suffix + " bytes")
	suite.check(loaded.reset_progress() and not loaded.save_blocked and not loaded.storage.read_candidate(path).is_empty(), "Explicit reset can replace unreadable progress")
	loaded.data.settings["future_setting"] = true
	suite.check(loaded.save(), "Additional settings can be saved")
	var again := VigilState.new()
	again.save_path = path
	suite.check(again.load_save() and again.data.settings.get("future_setting", false), "Loading preserves unrelated future settings")
	suite.clean_test_save(path)
	var fresh := VigilState.new()
	fresh.save_path = path
	suite.check(not fresh.load_save() and not fresh.save_blocked, "Missing save is a normal new game")

static func write_candidate(path: String, data: Dictionary) -> void:
	var payload := JSON.stringify(data)
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
