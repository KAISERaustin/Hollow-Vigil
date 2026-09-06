extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if active(context, config):
		stats.relic_damage_multiplier *= config.damage_multiplier
		stats.relic_pierce = stats.relic_pierce or config.defense_bypass > 0.0
