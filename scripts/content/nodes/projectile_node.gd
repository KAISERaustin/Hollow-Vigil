extends "res://scripts/content/nodes/content_node.gd"

func shot(origin: Vector2, target: Vector2, stats: Dictionary, target_id: int = -1, ballistic: bool = false) -> Dictionary:
	var muzzle: Vector2 = origin + _attributes.muzzle
	var flight: float = muzzle.distance_to(target) / _attributes.speed
	if not ballistic:
		flight = clampf(flight, _attributes.min_flight, _attributes.max_flight)
	return make_record({"tower_kind": _rules.kind, "from": muzzle, "pos": target, "target_id": target_id,
		"flight": flight, "life": flight + _attributes.impact_time, "max_life": flight + _attributes.impact_time,
		"color": stats.color, "radius": stats.splash})
