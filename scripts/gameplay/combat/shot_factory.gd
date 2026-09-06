extends RefCounted

# Combat uses this flight duration to resolve damage when the visual arrives.
# Target identities track centers without retaining pooled enemy dictionaries.
static func shot(kind: String, origin: Vector2, target: Vector2, stats: Dictionary, target_id: int = -1) -> Dictionary:
	var muzzle := origin + Vector2(0, -25)
	var speed := 760.0
	var min_flight := 0.10
	var max_flight := 0.22
	var impact_time := 0.09
	match kind:
		"electric":
			muzzle = origin + Vector2(0, -29)
			min_flight = 0.0
			max_flight = 0.0
			impact_time = 0.30
		"heavy":
			muzzle = origin + Vector2(0, -22)
			speed = 470.0
			min_flight = 0.18
			max_flight = 0.36
			impact_time = 0.18
		"splash":
			muzzle = origin + Vector2(0, -29)
			speed = 520.0
			min_flight = 0.17
			max_flight = 0.30
			impact_time = 0.24
	var flight := clampf(muzzle.distance_to(target) / speed, min_flight, max_flight)
	return {"kind": "shot", "tower_kind": kind, "from": muzzle, "pos": target, "target_id": target_id,
		"flight": flight, "life": flight + impact_time, "max_life": flight + impact_time,
		"color": stats.color, "radius": stats.splash}
