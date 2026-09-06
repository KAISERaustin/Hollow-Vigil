extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if context.target != context.previous_target or context.now - context.last >= config.reset_timeout:
		state.remaining = int(config.opening_attacks)
	if state.get("remaining", 0) > 0:
		stats.period /= 1.0 + config.opening_speed / 100.0
		state.remaining -= 1

func retune(state: Dictionary, _now: float, _before: Dictionary, after: Dictionary) -> void:
	state.remaining = mini(int(state.get("remaining", 0)), int(after.opening_attacks))
