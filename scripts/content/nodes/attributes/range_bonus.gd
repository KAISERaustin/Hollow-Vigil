extends "res://scripts/content/nodes/attribute_node.gd"

func modify_stats(stats: Dictionary, config: Dictionary) -> void:
	stats.range *= 1.0 + config.range_percent / 100.0
