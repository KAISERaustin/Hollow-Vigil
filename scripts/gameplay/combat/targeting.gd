extends RefCounted

# Target ranking depends only on the supplied candidates and route geometry.

static func distance_remaining(enemy: Dictionary) -> float:
	var geometry = enemy.get("_route_geometry")
	if geometry != null and is_same(geometry.points, enemy.path):
		return geometry.remaining(enemy.pos, enemy.segment)
	# Standalone helpers and externally replaced mutable paths remain supported.
	return exact_distance_remaining(enemy)

static func exact_distance_remaining(enemy: Dictionary) -> float:
	var path: Array = enemy.path
	var segment: int = enemy.segment
	var remaining: float = enemy.pos.distance_to(path[segment])
	for i in range(segment, path.size() - 1):
		remaining += path[i].distance_to(path[i + 1])
	return remaining

static func select_target(candidates: Array, pos: Vector2, radius: float, mode: String) -> Dictionary:
	var target: Dictionary = {}
	var best_score := 0.0
	var best_distance := 0.0
	for enemy in candidates:
		if enemy.dead or pos.distance_squared_to(enemy.pos) > radius * radius:
			continue
		if enemy.distance_remaining < 0.0:
			enemy.distance_remaining = distance_remaining(enemy)
		var remaining: float = enemy.distance_remaining
		# Suffix summation changes addition order. Resolve nearly equal ranks with
		# the original forward sum so ties keep their historical spawn-ID order.
		if not target.is_empty() and absf(remaining - best_distance) <= maxf(1.0, absf(remaining)) * 1.0e-10:
			remaining = exact_distance_remaining(enemy)
			best_distance = exact_distance_remaining(target)
			best_score = target.hp if mode == "most_hp" else (best_distance if mode == "last" else -best_distance)
		var score: float = enemy.hp if mode == "most_hp" else (remaining if mode == "last" else -remaining)
		# Equal HP prefers First; exact ties use spawn ID, never bucket order.
		if target.is_empty() or score > best_score or (score == best_score and (remaining < best_distance or (remaining == best_distance and enemy.id < target.id))):
			target = enemy
			best_score = score
			best_distance = remaining
	return target
