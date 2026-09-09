extends "res://scripts/content/nodes/attribute_node.gd"

## Stateless proximity bonus; the owning service combines overlapping sources.
func aura_bonus(source: Vector2, recipient: Vector2, config: Dictionary) -> float:
	if source.distance_squared_to(recipient) > pow(config.range, 2): return 0.0
	return maxf(0.0, config.get("aura_damage_percent", 0.0))
