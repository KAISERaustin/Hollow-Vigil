extends "res://tests/test_runner.gd"

func run() -> void:
	const Stats = preload("res://scripts/content/catalogs/stats.gd")
	const Relics = preload("res://scripts/gameplay/progression/relics.gd")
	var game := VigilState.new(901, "creative")
	game.combat.scripted_spawns = true
	var path: Array[Vector2] = [Vector2.ZERO, Vector2(10000, 0)]
	for category in ["enemies", "bosses"]:
		for kind in Balance.definitions(category):
			var overrides := {}
			for ability in Stats.capabilities(category):
				overrides = Stats.attach(overrides, category, kind, ability)
			for field in Stats.Capabilities.RESISTANCES:
				overrides = Stats.edit(overrides, category, kind, field, 100)
			check(game.apply_balance(overrides), "Legacy rules still load: " + kind)
			var enemy: Dictionary = game.combat.Bosses.create(game.combat, "0,0", kind, path) if category == "bosses" else game.combat.spawn_on_path(kind, path)
			for ability in Stats.capabilities(category):
				check(not game.combat.EnemyCapabilities.has(enemy, ability, overrides), "Removed ability stays inactive: " + kind + "/" + ability)
			for field in Stats.Capabilities.RESISTANCES:
				check(game.combat.EnemyCapabilities.resistance(enemy, field, overrides) == 1.0, "Removed resistance stays inactive: " + kind + "/" + field)
			check(enemy.shield == 0 and enemy.wards == 0, "No active defenses: " + kind)
			check(game.combat.EnemyCapabilities.damage(enemy, 20, [], false, overrides, false) == 20, "Ordinary damage: " + kind)
			for field in Stats.schema(category):
				if Stats.editable_stat(category, field): check(field in ["hp", "speed", "payout", "escape_damage"], "Actor editor contains only stats")
			game.combat.enemies.clear()
	var tower := Balance.Content.tower("rapid").create("1", "0,0", 0)
	game.data.towers["1"] = tower
	for kind in Balance.GEAR:
		game.data.relics = {"0,0": kind}
		tower.relic = "0,0"
		check(Relics.kind(game.data, tower).is_empty(), "Saved gear inactive: " + kind)
		check(not Relics.award(game.data, "1,1", kind), "No new gear rewards: " + kind)
		check(not game.economy.equip_relic("1", "0,0", "0,0"), "Cannot equip gear")
		var overrides := Stats.attach({}, "towers", "rapid", "gear_" + kind)
		check(Balance.tower_stats(tower, overrides, game.data.relics).damage == Balance.stats("rapid", 1).damage, "Old assigned/equipped gear adds no stats")
		check(game.combat.StatComposition.direct_gear(tower, overrides, game.data.relics).is_empty(), "No assigned gear effects")
	for kind in Balance.TOWERS:
		for ability in Stats.Capabilities.defaults("towers", kind): check(Stats.ability_enabled("towers", kind, ability, {}), "Built-in tower behavior preserved")
	print("SIMPLIFIED RULES: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
