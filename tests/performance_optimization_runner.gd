extends "res://tests/test_runner.gd"

const F = preload("res://tests/performance/fixtures.gd")
const Targeting = preload("res://scripts/gameplay/combat/targeting.gd")

func run() -> void:
	routes()
	configuration()
	pooling()
	print("PERFORMANCE OPTIMIZATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func routes() -> void:
	var game := F.infinite(4, false)
	game.combat.enemies.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 71583
	for trial in range(32):
		var path: Array[Vector2] = [Vector2.ZERO]
		for index in range(60): path.append(path[-1] + Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300)))
		var actors := []
		for segment in range(1, path.size()):
			for fraction in [0.0, 0.5, 1.0, 1.001]:
				var enemy := {"id": actors.size(), "path": path, "segment": segment,
					"pos": path[segment-1].lerp(path[segment], fraction), "hp": 100.0, "dead": false}
				game.combat.set_enemy_route(enemy, path)
				var exact := Targeting.exact_distance_remaining(enemy)
				check(absf(Targeting.distance_remaining(enemy) - exact) <= maxf(1.0, exact) * 2.0e-13, "Route suffix preserves distance within floating-point summation error")
				actors.append(enemy)
		check(is_same(actors[0].path, actors[-1].path), "Identical actual routes share immutable geometry")
		var reference := actors.duplicate(true)
		for enemy in reference: enemy.erase("_route_geometry"); enemy.distance_remaining = -1.0
		for mode in ["first", "last", "most_hp"]:
			check(Targeting.select_target(actors, Vector2.ZERO, 1e8, mode).id == Targeting.select_target(reference, Vector2.ZERO, 1e8, mode).id, "Cached target ordering equals forward-sum reference")
		var retained: Vector2 = actors[0].path[1]
		path[1] += Vector2(31, -19)
		check(actors[0].path[1] == retained, "External waypoint edits cannot mutate an enemy's assigned route")
		game.combat.set_enemy_route(actors[0], path)
		check(actors[0].path[1] == path[1] and actors[-1].path[1] == retained, "Explicit replacement affects only its recipient")
		# Direct legacy/editor path replacement safely uses the original calculation.
		actors[0].path = path
		check(Targeting.distance_remaining(actors[0]) == Targeting.exact_distance_remaining(actors[0]), "Mutable replacement never reads stale geometry")
	var enemy := game.combat.spawn("-4,0", "basic")
	var geometry = enemy._route_geometry
	var points: Array = enemy.path
	game.data.regions["-5,0"] = VigilWorld.make_region("-5,0", "-4,0", 570)
	game.refresh_paths()
	check(is_same(enemy.path, points) and enemy._route_geometry == geometry, "World expansion retains the live enemy's intended route")
	enemy.segment = mini(5, enemy.path.size()-1)
	enemy.pos = enemy.path[enemy.segment]
	game.combat.push_back(enemy, 125)
	check(is_equal_approx(Targeting.distance_remaining(enemy), Targeting.exact_distance_remaining(enemy)), "Knockback uses current position and segment")

func legacy_speed(game: VigilState, enemy: Dictionary) -> float:
	var now := game.combat.simulation_time
	if enemy.get("stun_until", 0.0) > now or enemy.get("root_until", 0.0) > now or game.combat.Relics.strength(enemy, "stun", now) > 0.0: return 0.0
	var speed: float = game.combat.Bosses.speed(enemy, now, game.tuning) if enemy.get("boss", false) else Balance.tuned_value("enemies", enemy.kind, "speed", game.tuning)
	if enemy.get("rift_style", "forest") == "drowned_crypt": speed *= Balance.rift_speed_multiplier("drowned_crypt", game.tuning)
	var slow := game.combat.Relics.strength(enemy, "slow", now)
	if enemy.get("slow_until", 0.0) > now: slow = maxf(slow, enemy.get("slow_percent", 25.0))
	return speed * (1.0 - slow / 100.0)

func configuration() -> void:
	var game := F.infinite(4, true)
	for boss in [false, true]:
		for kind in (Balance.BOSSES if boss else Balance.ENEMIES):
			for style in Balance.RIFTS:
				for state in [{}, {"slow_until": 10.0, "slow_percent": 37.0}, {"stun_until": 10.0}, {"root_until": 10.0}, {"gear_status": {"a": {"type": "slow", "until": 10.0, "strength": 46.0}}}, {"gear_status": {"a": {"type": "stun", "until": 10.0, "strength": 100.0}}}]:
					var enemy := {"kind": kind, "boss": boss, "rift_style": style, "hp": 1.0, "max_hp": 100.0}
					enemy.merge(state)
					check(game.combat.enemy_speed(enemy) == legacy_speed(game, enemy), "Cached base speed preserves each live modifier")
	var basic := {"kind": "basic", "rift_style": "forest"}
	var original := game.combat.enemy_speed(basic)
	game.data.settings.developer_balance = {"enemies": {"basic": {"speed": original + 7.0}}}
	check(game.combat.enemy_speed(basic) == original + 7.0, "Configuration replacement invalidates speeds")
	game.data.settings.developer_balance.enemies.basic.speed += 3.0
	check(game.combat.enemy_speed(basic) == original + 10.0, "In-place tuning invalidates speeds")
	var other := F.infinite(4, false)
	check(other.combat.enemy_speed(basic) == original, "Resolved configuration is session-local")
	for tower in game.data.towers.values():
		check(game.combat.tower_stats(tower) == Balance.tower_stats(tower, game.tuning, game.data.relics), "Cached tower stats match owner resolution")
		game.data.relics["test"] = "warden"
		tower.relic = "test"
		check(game.combat.tower_stats(tower) == Balance.tower_stats(tower, game.tuning, game.data.relics), "Equipment changes invalidate stats")
		tower.level = 1; tower.branch = ""
		check(game.combat.tower_stats(tower) == Balance.tower_stats(tower, game.tuning, game.data.relics), "Tier changes invalidate stats")

func pooling() -> void:
	var game := F.infinite(4, false)
	game.combat.enemies.clear()
	for index in range(300):
		var enemy := game.combat.spawn("-4,0", "basic")
		game.combat.set_enemy_route(enemy, [Vector2(index, 0), Vector2.ZERO])
		enemy.dead = true
		game.combat.recycle_dead_enemies()
		check(game.combat.enemy_index.identifiers.is_empty(), "Recycled dictionaries leave identifier map immediately")
	game.combat.route_cache.prune()
	check(game.combat.route_cache.routes.is_empty(), "Unused route geometries are released after recycling")
	check(game.combat.configuration.towers.is_empty(), "Empty combat retains no tower statistics")
