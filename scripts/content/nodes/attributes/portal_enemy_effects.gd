extends "res://scripts/content/nodes/attribute_node.gd"
## Stateless recipient modifiers; mutable health belongs to each enemy.
func incoming_damage(amount: float, config: Dictionary) -> float:
	return amount * (1.0 - clampf(float(config.get("armor_percent", 0.0)), 0.0, 100.0) / 100.0)

func advance(enemy: Dictionary, delta: float, config: Dictionary) -> void:
	if enemy.get("dead", false) or delta <= 0.0: return
	var percent := float(config.get("health_regen_percent", 0.0))
	enemy.hp = minf(enemy.max_hp, enemy.hp + enemy.max_hp * percent / 100.0 * delta)
