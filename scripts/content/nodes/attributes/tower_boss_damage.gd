extends "res://scripts/content/nodes/attribute_node.gd"

func before_hit(_combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	if enemy.get("boss", false): shot.damage *= config.get("boss_damage_multiplier", 1.5)
