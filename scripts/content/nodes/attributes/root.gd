extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	stats.relic_root = context.now >= state.get("root_ready", 0.0)
	if stats.relic_root:
		state.root_ready = context.now + config.root_period
		effect(stats, config)

func impact(combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	combat.Relics.apply_root(combat, shot, enemy, config)

func retune(state: Dictionary, now: float, before: Dictionary, after: Dictionary) -> void:
	state.root_ready = now + after.root_period * clampf((state.get("root_ready", now) - now) / before.root_period, 0.0, 1.0)
