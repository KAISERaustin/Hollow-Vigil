extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if active(context, config):
		effect(stats, config)

func impact(combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	if enemy.id != shot.get("target_id", -1) or enemy.get("gear_stun_immune_until", 0.0) > combat.simulation_time:
		return
	var duration: float = config.boss_duration if enemy.get("boss", false) else config.duration
	combat.Relics.add_status(enemy, shot.tower_id, id, {"type": "stun", "until": combat.simulation_time + duration})
	enemy.gear_stun_immune_until = combat.simulation_time + config.stun_immunity
