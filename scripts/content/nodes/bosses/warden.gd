extends "res://scripts/content/nodes/boss_node.gd"

func absorb_damage(enemy: Dictionary, amount: float, _branch: String, fire: bool, tuning: Dictionary = {}, pierce: bool = false) -> float:
	if not pierce and enemy.shield > 0.0:
		var stats := definition(tuning)
		var multiplier: float = stats.fire_multiplier if fire else 1.0
		var absorbed := minf(enemy.shield, amount * multiplier)
		enemy.shield -= absorbed
		amount -= absorbed / multiplier
	return amount
