extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	state.stacks = mini(int(config.stack_limit), int(state.get("stacks", 0)) + 1) if context.target == context.previous_target and context.now - context.last < config.stack_timeout else 0
	if rule("stat") == "speed":
		stats.period /= 1.0 + state.stacks * config.speed_per_stack / 100.0
	else:
		stats.relic_damage_multiplier *= 1.0 + state.stacks * config.damage_per_stack / 100.0

func retune(state: Dictionary, _now: float, _before: Dictionary, after: Dictionary) -> void:
	state.stacks = mini(int(state.get("stacks", 0)), int(after.stack_limit))
