extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if active(context, config):
		effect(stats, config)

func impact(combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	if enemy.id != shot.get("target_id", -1):
		return
	var status := {"type": rule("effect"), "until": combat.simulation_time + config.duration}
	match rule("effect"):
		"dot":
			status.damage = shot.base_damage * config.dot_multiplier
			status.fire = config.get("fire_damage", 0.0) > 0.0
		"slow":
			status.strength = config.slow_percent
			status.until = combat.simulation_time + (config.boss_duration if enemy.get("boss", false) else config.duration)
		"expose": status.strength = config.vulnerability_percent
	if config.has("ability"):
		status.ability = config.ability
		status.component_slot = config.component_slot
		status.component = config.component
		status.component_config = config.component_config
	combat.Relics.add_status(enemy, shot.tower_id, config.get("status_id", id), status)
