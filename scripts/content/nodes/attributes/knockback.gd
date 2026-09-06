extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if active(context, config):
		effect(stats, config)

func impact(combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	if enemy.id != shot.get("target_id", -1) or enemy.get("gear_push_until", 0.0) > combat.simulation_time:
		return
	var resistance: float = combat.Relics.push_resistance(combat, enemy)
	combat.push_back(enemy, config.push_distance * (1.0 - resistance / 100.0))
	enemy.gear_push_until = combat.simulation_time + config.push_immunity
