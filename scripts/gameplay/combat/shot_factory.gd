extends RefCounted

# Combat uses this flight duration to resolve damage when the visual arrives.
# Target identities track centers without retaining pooled enemy dictionaries.
static func shot(kind: String, origin: Vector2, target: Vector2, stats: Dictionary, target_id: int = -1, ballistic: bool = false) -> Dictionary:
	var profile: Dictionary = Balance.PROJECTILES[kind]
	var muzzle: Vector2 = origin + profile.muzzle
	var flight: float = muzzle.distance_to(target) / profile.speed
	if not ballistic:
		flight = clampf(flight, profile.min_flight, profile.max_flight)
	return {"kind": "shot", "tower_kind": kind, "from": muzzle, "pos": target, "target_id": target_id,
		"flight": flight, "life": flight + profile.impact_time, "max_life": flight + profile.impact_time,
		"color": stats.color, "radius": stats.splash}
