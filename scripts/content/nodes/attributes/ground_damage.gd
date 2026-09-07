extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if active(context, config):
		effect(stats, config)

func arrive(combat, shot: Dictionary, config: Dictionary) -> void:
	combat.EffectFields.add(combat, shot, self, config)
