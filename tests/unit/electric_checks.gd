extends RefCounted

static func run(suite: SceneTree) -> void:
	for level in [1, 2, 3]:
		for mode in Balance.TARGET_MODES:
			var game := VigilState.new(719)
			game.data.balance = 10000.0
			game.expand("1,0")
			game.data.regions["1,0"].style = "forest" # Measure lightning without biome effects.
			game.data.regions["1,0"].timer = 9.0
			var id := game.economy.build("electric", "0,0", 0)
			for current in range(1, level):
				suite.check(game.economy.upgrade(id, current), "Stormspire upgrade succeeds")
			game.data.towers[id].target_mode = mode
			var stats := Balance.stats("electric", level)
			suite.check(stats.targets == 5 and stats.damage < Balance.stats("rapid", level).damage, "Stormspire has five targets at every level")
			var origin := VigilWorld.pad_position("0,0", 0)
			var victims: Array[Dictionary] = []
			for index in range(Balance.ENEMIES.size() + 1):
				var kind: String = Balance.ENEMIES.keys()[index % Balance.ENEMIES.size()]
				game.data.regions["1,0"].style = "castle_ruin" if kind in Balance.DUNGEON_KINDS else "forest"
				var enemy: Dictionary = suite.fixture_enemy(game, kind)
				enemy.pos = origin + Vector2.from_angle(index * TAU / Balance.ENEMIES.size()) * (80.0 if index < Balance.ENEMIES.size() else 500.0)
				enemy.path = [enemy.pos, enemy.pos + Vector2(1000 + index * 100, 0)]
				enemy.hp = 100.0 + index * 10.0
				victims.append(enemy)
			game.combat.tick(Balance.STEP)
			var count := 0
			for index in range(victims.size()):
				var damage: float = 100.0 + index * 10.0 - victims[index].hp
				if damage > 0:
					count += 1
					suite.check(damage == stats.damage and index < Balance.ENEMIES.size(), "Each in-range target takes exactly one zap")
				var selected: bool = index < stats.targets if mode == "first" else (index < Balance.ENEMIES.size() and index >= Balance.ENEMIES.size() - stats.targets)
				suite.check((damage > 0) == selected, "Lightning selects the top targets for " + mode)
			var shots := game.combat.effects.filter(func(fx): return fx.kind == "shot")
			suite.check(count == stats.targets and shots.size() == count, "Lightning respects its cap across widely separated enemies")
			# Switch priority before the old arcs fade; previous connections must end.
			game.data.towers[id].target_mode = "last" if mode == "first" else "first"
			game.data.towers[id].cooldown = 0.0
			game.combat.tick(Balance.STEP)
			shots = game.combat.effects.filter(func(fx): return fx.kind == "shot")
			suite.check(shots.size() == 5, "Retargeting replaces old arcs and keeps five simultaneous connections")
			game.combat.enemies.clear()
			game.data.regions["1,0"].style = "forest"
			for index in range(6):
				var enemy := game.combat.spawn("1,0", "basic")
				enemy.pos = origin
				enemy.path = [origin, origin + Vector2(1000, 0)]
				enemy.hp = stats.damage
			game.data.towers[id].cooldown = 0.0
			game.combat.tick(Balance.STEP)
			suite.check(game.data.kills == stats.targets and game.data.towers[id].earnings == stats.targets * Balance.ENEMIES.basic.payout, "Lethal zaps credit each victim exactly once")
			suite.check(game.storage.valid_data(game.snapshot(1000.0)), "Stormspire level and targeting are valid saved data")
	print("PASS GROUP: electricity caps, priority, range, tier damage and exact rewards")
