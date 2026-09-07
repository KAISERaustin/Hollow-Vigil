extends "res://scripts/content/nodes/attribute_node.gd"

func allows_empty_target() -> bool:
	return true

func ready(combat, tower: Dictionary, origin: Vector2, stats: Dictionary) -> bool:
	return not preload("res://scripts/gameplay/combat/road_traps.gd").positions(combat, tower, origin, {}, stats).is_empty()

func attack(combat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	preload("res://scripts/gameplay/combat/road_traps.gd").deploy(combat, tower, origin, target, stats)
