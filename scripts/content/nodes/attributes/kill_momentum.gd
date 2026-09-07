extends "res://scripts/content/nodes/attribute_node.gd"

func credited_kill(state: Dictionary, now: float, config: Dictionary) -> void:
	var previous := int(state.get("stacks", 0)) if now - state.get("last_kill", -INF) < config.stack_timeout else 0
	state.stacks = mini(int(config.stack_limit), previous + 1)
	state.last_kill = now

func prepare(state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if context.now - state.get("last_kill", -INF) >= config.stack_timeout:
		state.stacks = 0
	stats.relic_damage_multiplier *= 1.0 + int(state.get("stacks", 0)) * config.damage_per_stack / 100.0

func retune(state: Dictionary, now: float, _before: Dictionary, after: Dictionary) -> void:
	state.stacks = mini(int(state.get("stacks", 0)), int(after.stack_limit)) if now - state.get("last_kill", -INF) < after.stack_timeout else 0
