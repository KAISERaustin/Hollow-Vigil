extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	stats.relic_echo = active(context, config)
	if stats.relic_echo:
		stats.gear_echoes.append({"multiplier": config.echo_multiplier, "delay": config.echo_delay})
