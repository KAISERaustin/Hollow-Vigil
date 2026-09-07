extends RefCounted

## Swept geometry supplies both gameplay positions and the rendered projectile.
static func aim_point(combat, target: Dictionary, muzzle: Vector2, speed: float) -> Vector2:
	# Lead along the known road once at launch; the projectile never homes.
	var aim: Vector2 = target.pos
	var path: Array = target.get("path", [])
	var move_speed: float = combat.enemy_speed(target)
	for iteration in range(6):
		var travel := muzzle.distance_to(aim) / maxf(1.0, speed) * move_speed
		aim = target.pos
		for index in range(int(target.get("segment", 1)), path.size()):
			var distance := aim.distance_to(path[index])
			if travel <= distance:
				aim = aim.move_toward(path[index], travel)
				break
			travel -= distance
			aim = path[index]
	return aim

static func launch(combat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary, returning: bool) -> void:
	var profile: Dictionary = Balance.PROJECTILES[tower.kind]
	var muzzle: Vector2 = origin + profile.muzzle
	var direction: Vector2 = (aim_point(combat, target, muzzle, profile.speed) - muzzle).normalized()
	if direction.is_zero_approx(): direction = Vector2.UP
	# The weapon and swept bolt share the muzzle-based bearing, including volleys.
	tower.angle = direction.angle()
	var normal := direction.orthogonal()
	var volley := {}
	var arrival := {"resolved": false}
	var count := 1 if returning else int(stats.get("volley_count", 1))
	for index in range(count):
		var start: Vector2 = muzzle + normal * (index - (count - 1) / 2.0) * stats.get("volley_spacing", 20.0)
		var relative: Vector2 = start - origin
		var b := relative.dot(direction)
		var length := maxf(1.0, -b + sqrt(maxf(0.0, b * b + stats.range * stats.range - relative.length_squared())))
		var shot: Dictionary = combat.Projectiles.make_shot(combat, tower, origin, target, stats, index == 0)
		combat.line_projectiles.append({"tower_id": tower.id, "epoch": combat.TowerComponents.ensure(combat, tower).epoch,
			"shot": shot, "start": start, "end": start + direction * length, "pos": start, "direction": direction,
			"speed": profile.speed, "return_speed": stats.get("return_speed", 1.0), "returning": returning, "leg": 0,
			"hits": {}, "volley": volley, "limit": int(stats.get("pierce_count", 3)), "width": stats.get("projectile_width", 9.0),
			"loss": stats.get("pierce_loss", 0.0), "floor": stats.get("pierce_floor", 1.0), "age": 0.0, "arrival": arrival})
	combat.Projectiles.launch_extras(combat, tower, origin, target, stats)

static func advance(combat, delta: float) -> void:
	var live: Array[Dictionary] = []
	for projectile in combat.line_projectiles:
		if not combat.TowerComponents.valid(combat, projectile.tower_id, projectile.epoch): continue
		projectile.age += delta
		var time := delta
		var done := false
		while time > 0.000001 and not done:
			var destination: Vector2 = projectile.end if projectile.leg == 0 else projectile.start
			var speed: float = projectile.speed * (1.0 if projectile.leg == 0 else projectile.return_speed)
			var distance: float = projectile.pos.distance_to(destination)
			var used := minf(time, distance / maxf(1.0, speed))
			var next: Vector2 = projectile.pos.move_toward(destination, speed * used)
			collide(combat, projectile, projectile.pos, next)
			projectile.pos = next
			time -= used
			if distance <= speed * used + 0.00001:
				if projectile.returning and projectile.leg == 0:
					projectile.leg = 1
					projectile.hits = {}
				else: done = true
		if not done: live.append(projectile)
	combat.line_projectiles = live

static func collide(combat, projectile: Dictionary, start: Vector2, end: Vector2) -> void:
	if projectile.hits.size() >= projectile.limit: return
	if not combat.ticking: combat.rebuild_enemy_index()
	var candidates := []
	for enemy in combat.enemy_index.query_rect(Rect2(start, Vector2.ZERO).expand(end).grow(projectile.width)):
		if enemy.dead or projectile.hits.has(enemy.id) or (not projectile.returning and projectile.volley.has(enemy.id)): continue
		var point := Geometry2D.get_closest_point_to_segment(enemy.pos, start, end)
		if point.distance_squared_to(enemy.pos) <= projectile.width * projectile.width:
			candidates.append({"enemy": enemy, "distance": start.distance_squared_to(point)})
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	for candidate in candidates:
		if projectile.hits.size() >= projectile.limit: break
		var enemy: Dictionary = candidate.enemy
		if enemy.dead: continue
		var shot: Dictionary = projectile.shot.duplicate()
		shot.fx = shot.fx.duplicate()
		shot.fx.pos = enemy.pos
		shot.fx.flight = 0.0
		shot.target_id = enemy.id
		shot.damage *= maxf(projectile.floor, 1.0 - projectile.hits.size() * projectile.loss)
		projectile.hits[enemy.id] = true
		projectile.volley[enemy.id] = true
		# Area gear procs occur once per volley/throw, while on-hit gear still
		# applies at each actual contact, including the return leg.
		shot.skip_gear_arrival = projectile.arrival.resolved
		if shot.has("gear_effects"): projectile.arrival.resolved = true
		combat.resolve_shot(shot, enemy)
