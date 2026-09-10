extends "res://scripts/content/nodes/attribute_node.gd"

## Applied at effect evaluation so saving a resistance updates existing effects.
func multiplier(stats: Dictionary) -> float:
	return 1.0 - clampf(float(stats.get(rule("stat"), 0.0)), 0.0, 100.0) / 100.0
