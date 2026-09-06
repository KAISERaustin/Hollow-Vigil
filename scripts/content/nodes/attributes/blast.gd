extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if active(context, config):
		stats.relic_radius = maxf(stats.relic_radius, config.blast_radius)
