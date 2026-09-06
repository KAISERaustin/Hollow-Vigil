extends RefCounted

const Fixture = preload("res://tests/support/orchard_fixture.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")

static func run(suite: SceneTree) -> void:
	var locations := {}
	for seed_value in range(1, 101):
		var cells := VigilWorld.Orchard.cluster(seed_value)
		locations[VigilWorld.Orchard.gate(seed_value)] = true
		suite.check(cells.size() >= 6 and cells.size() <= 9, "Orchard patch has six to nine tiles")
		var visited: Array[Vector2i] = [cells[0]]
		var head := 0
		while head < visited.size():
			for direction in VigilWorld.DIRS:
				var neighbor: Vector2i = visited[head] + direction
				if cells.has(neighbor) and not visited.has(neighbor):
					visited.append(neighbor)
			head += 1
		suite.check(visited.size() == cells.size(), "All Orchard tiles form one connected patch")
		var count := 0
		var portals := 0
		for y in range(-12, 13):
			for x in range(-12, 13):
				var id := VigilWorld.key(Vector2i(x,y))
				if VigilWorld.region_style(id, seed_value) != "mourning_orchard":
					continue
				count += 1
				suite.check(not VigilWorld.is_ruin(id, seed_value) and maxi(absi(x),absi(y)) >= 3, "Orchard preserves castle ruins and the opening")
				if VigilWorld.has_rift(id, {id: {"style": "mourning_orchard"}}, seed_value):
					portals += 1
		suite.check(count == cells.size() and portals == 1, "Exactly one patch and one portal across the world generation bounds")
		VigilWorld.Orchard.cache.erase(seed_value)
		suite.check(cells == VigilWorld.Orchard.cluster(seed_value), "Orchard regenerates identically after cache eviction")
	suite.check(locations.size() > 70, "World seeds randomize the Orchard location")
	var game := VigilState.new(879)
	var gate := Fixture.populate(game)
	game.data.balance = 1e9
	var seen := {}
	for i in range(300):
		var enemy := game.combat.spawn(gate)
		suite.check(enemy.kind in Balance.ORCHARD_KINDS and enemy.pos == VigilWorld.center(gate), "Only Orchard inhabitants emerge at the actual portal")
		seen[enemy.kind] = true
	suite.check(seen.size() == 3, "All three inhabitants spawn without attunements")
	game.combat.enemies.clear()
	for cell in VigilWorld.Orchard.cluster(879):
		var id := VigilWorld.key(cell)
		if id != gate:
			suite.check(game.combat.spawn(id).is_empty() and not game.economy.buy_traffic(id), "Path-only Orchard tile cannot spawn or buy traffic")
	for kind in Balance.NORMAL_KINDS + Balance.DUNGEON_KINDS:
		suite.check(game.combat.spawn(gate,kind).is_empty() and game.combat.spawn(gate,kind,true).is_empty(), "Orchard rejects other portal inhabitants, including escorts")
	for kind in Balance.UNLOCK_COSTS:
		suite.check(not game.economy.unlock(gate,kind), "Orchard rejects ordinary attunements")
	var period := game.economy.spawn_period(gate)
	suite.check(game.economy.buy_traffic(gate) and game.economy.spawn_period(gate) < period, "Orchard traffic upgrades work")
	for kind in Balance.ORCHARD_KINDS:
		var normal: Dictionary = suite.fixture_enemy(game)
		suite.check(game.combat.spawn(normal.source,kind).is_empty() and game.combat.spawn(normal.source,kind,true).is_empty() and game.combat.spawn(gate,kind,true).is_empty(), "Orchard enemies cannot leak through normal spawns or escorts")
		game.combat.enemies.clear()
		var enemy := game.combat.spawn(gate,kind)
		var start: Vector2 = enemy.pos
		game.combat.tick(Balance.STEP)
		suite.check(absf(start.distance_to(enemy.pos) - Balance.ENEMIES[kind].speed * Balance.STEP) < 0.001, "Orchard enemy follows the road at its own speed")
		var tower := game.economy.build("heavy",gate,Balance.ORCHARD_KINDS.find(kind))
		suite.check(game.combat.hit(enemy,1e6,tower) and not game.combat.hit(enemy,1e6,tower), "Orchard defeats pay only once")
		suite.check(game.data.towers[tower].earnings == Balance.ENEMIES[kind].payout and game.data.regions[gate].history[tower] == Balance.ENEMIES[kind].payout, "Orchard gold participates in collection and offline history")
		for stat in Balance.fields_for("enemies",kind):
			var value: float = {"hp": 333.0,"speed":51.0,"payout":37.0,"push_resistance":62.0}[stat]
			suite.check(game.set_balance_stat("enemies",kind,stat,value), "Developer can edit every Orchard enemy stat")
	# Natural timers run without a rendered battlefield.
	game.combat.enemies.clear()
	game.data.regions[gate].timer = 0.0
	game.combat.tick(Balance.STEP)
	suite.check(game.combat.enemies.size() == 1 and game.combat.enemies[0].kind in Balance.ORCHARD_KINDS, "Offscreen Orchard portal advances on simulation time")
	game.save_path = "user://orchard-unit.save"
	for region in game.data.regions.values():
		region.timer = 1.0
	suite.clean_test_save(game.save_path)
	suite.check(game.save(1000.0), "Orchard world and tuning save")
	var loaded := VigilState.new()
	loaded.save_path = game.save_path
	suite.check(loaded.load_save(1000.0) and loaded.data.regions[gate].style == "mourning_orchard" and loaded.tuning == game.tuning, "Orchard terrain and developer edits reload exactly")
	var code := VigilSaveSlots.new().export_build(game,"Mourning Orchard test")
	var decoded := VigilSaveSlots.new().decode_build(code)
	suite.check(not decoded.is_empty() and decoded.settings.developer_balance == game.tuning and decoded.regions[gate].style == "mourning_orchard", "Exported configuration retains terrain and all enemy edits")
	var codec := Codec.new()
	var cloud := codec.encode(game.snapshot(), Codec.uuid())
	var restored := codec.decode(cloud,{},[0.0,0.0,1.0])
	suite.check(not restored.is_empty() and restored.settings.developer_balance == game.tuning and restored.regions[gate].style == "mourning_orchard", "Cloud codec preserves Orchard content and tuning")
	suite.clean_test_save(game.save_path)

	# Every tower and specialization can target, damage and pay for all new types.
	for tower_kind in Balance.TOWERS:
		for branch in [""] + Balance.BRANCHES[tower_kind].keys():
			for enemy_kind in Balance.ORCHARD_KINDS:
				var battle := VigilState.new(879)
				var source := Fixture.populate(battle)
				battle.data.balance = 1e9
				var tower := battle.economy.build(tower_kind,source,0)
				if branch != "":
					battle.economy.upgrade(tower)
					battle.economy.upgrade(tower)
					battle.economy.upgrade(tower,3,branch)
				battle.set_balance_stat("enemies",enemy_kind,"speed",1.0)
				var enemy := battle.combat.spawn(source,enemy_kind)
				enemy.pos = VigilWorld.pad_position(source,0) + Vector2(10,0)
				enemy.path = [enemy.pos,enemy.pos + Vector2(10000,0)]
				for region in battle.data.regions.values(): region.timer = 10000.0
				for tick in range(2400):
					battle.combat.tick(Balance.STEP)
					if enemy.dead: break
				suite.check(enemy.dead and battle.data.kills == 1 and battle.data.towers[tower].earnings == Balance.ENEMIES[enemy_kind].payout, tower_kind + "/" + branch + " defeats and rewards " + enemy_kind)
