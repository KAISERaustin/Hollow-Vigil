extends "res://scripts/content/nodes/content_node.gd"

## Optional rotating mounts share one pivot and muzzle contract with presentation.
## Definitions are immutable; the caller owns the instance's current bearing.
func aimed_launch(origin: Vector2, target: Vector2) -> Dictionary:
	var pivot: Vector2 = origin + _attributes.get("aim_pivot", _attributes.muzzle)
	var direction := (target - pivot).normalized()
	if direction.is_zero_approx(): direction = Vector2.UP
	var muzzle: Vector2 = origin + _attributes.muzzle
	if _attributes.has("aim_pivot"):
		var rotation := direction.angle() - float(_attributes.get("aim_forward", -PI / 2.0))
		muzzle = pivot + (_attributes.muzzle - _attributes.aim_pivot).rotated(rotation)
	return {"muzzle": muzzle, "direction": direction}

func shot(origin: Vector2, target: Vector2, stats: Dictionary, target_id: int = -1, ballistic: bool = false) -> Dictionary:
	var muzzle: Vector2 = aimed_launch(origin, target).muzzle
	var flight: float = muzzle.distance_to(target) / stats.get("projectile_speed", _attributes.speed)
	if not ballistic:
		flight = clampf(flight, _attributes.min_flight, _attributes.max_flight)
	return make_record({"tower_kind": _rules.kind, "from": muzzle, "pos": target, "target_id": target_id,
		"flight": flight, "life": flight + _attributes.impact_time, "max_life": flight + _attributes.impact_time,
		"color": stats.color, "radius": stats.splash})
