extends RefCounted

## Placement uses actual road segments in either mode, never terrain guesses.
static func positions(combat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> Array[Vector2]:
	var occupied: Array[Vector2] = []
	for trap in combat.traps:
		if trap.tower_id == tower.id: occupied.append(trap.pos)
	if occupied.size() >= int(stats.trap_capacity): return []
	var roads: Array = combat.authored_roads if combat.scripted_spawns else combat.paths.values()
	var aim: Vector2 = origin if target.is_empty() else target.pos
	var choices: Array[Vector2] = []
	for road in roads:
		for index in range(1, road.size()):
			var a: Vector2 = road[index - 1]
			var b: Vector2 = road[index]
			# Project first, so short or oblique segments retain a valid candidate.
			var closest := Geometry2D.get_closest_point_to_segment(aim, a, b)
			var samples: Array[Vector2] = [closest]
			var steps := maxi(1, ceili(a.distance_to(b) / 20.0))
			for step in range(steps + 1): samples.append(a.lerp(b, float(step) / steps))
			for sample in samples:
				if sample.distance_squared_to(origin) <= stats.range * stats.range and not choices.has(sample): choices.append(sample)
	choices.sort_custom(func(a, b): return a.distance_squared_to(aim) < b.distance_squared_to(aim))
	var result: Array[Vector2] = []
	for choice in choices:
		var clear := true
		for point in occupied:
			if point.distance_squared_to(choice) < 20.0 * 20.0: clear = false; break
		if not clear: continue
		result.append(choice)
		occupied.append(choice)
		if result.size() >= int(stats.trap_count) or occupied.size() >= int(stats.trap_capacity): break
	return result

static func deploy(combat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	var points := positions(combat, tower, origin, target, stats)
	for index in range(points.size()):
		var pos: Vector2 = points[index]
		var victim := {"id": -1, "pos": pos}
		var shot: Dictionary = combat.Projectiles.make_shot(combat, tower, origin, victim, stats, index == 0)
		shot.fx.pos = pos
		combat.traps.append({"tower_id": tower.id, "epoch": combat.TowerComponents.ensure(combat, tower).epoch,
			"pos": pos, "arm_at": combat.simulation_time + stats.trap_arm_time, "until": combat.simulation_time + stats.trap_duration,
			"radius": stats.trap_radius, "shot": shot, "stats": stats.duplicate(true), "primary": index == 0, "branch": tower.get("branch", "")})

static func advance(combat) -> void:
	var live: Array[Dictionary] = []
	for trap in combat.traps:
		if trap.until <= combat.simulation_time or not combat.TowerComponents.valid(combat, trap.tower_id, trap.epoch): continue
		var victim: Dictionary = {}
		if trap.arm_at <= combat.simulation_time:
			for enemy in combat.nearby_enemies(trap.pos, trap.radius):
				if not enemy.dead: victim = enemy; break
		if victim.is_empty(): live.append(trap); continue
		trap.shot.target_id = victim.id
		trap.shot.fx.flight = 0.0
		combat.resolve_shot(trap.shot, victim)
		var tower: Dictionary = combat.data.towers[trap.tower_id]
		combat.Projectiles.launch_extras(combat, tower, trap.pos, victim, trap.stats, trap.primary)
		combat.add_effect({"kind": "trap_snap", "pos": trap.pos, "color": trap.stats.color, "life": 0.25, "max_life": 0.25})
	combat.traps = live
