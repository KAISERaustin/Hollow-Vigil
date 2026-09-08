extends "res://scripts/content/nodes/boss_node.gd"

func movement_speed(enemy: Dictionary, now: float, tuning: Dictionary = {}, resolved: Dictionary = {}) -> float:
	var stats := definition(tuning) if resolved.is_empty() else resolved
	var value: float = stats.speed
	if enemy.hp <= enemy.max_hp * stats.rage_threshold / 100.0:
		var suppression: float = stats.quench / 100.0 if enemy.get("slow_until", 0.0) > now else 0.0
		value *= 1.0 + (stats.haste_multiplier - 1.0) * (1.0 - suppression)
	return value

func absorb_damage(enemy: Dictionary, amount: float, branch: String, _fire: bool, tuning: Dictionary = {}, pierce: bool = false) -> float:
	var stats := definition(tuning)
	if branch == "frostneedle":
		amount *= stats.frost_multiplier
	if not pierce and enemy.hp > enemy.max_hp * stats.rage_threshold / 100.0:
		amount *= 1.0 - stats.armor_reduction / 100.0
	return amount
