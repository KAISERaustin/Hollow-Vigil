extends "res://scripts/content/nodes/attribute_node.gd"

func allows_empty_target() -> bool:
	return true

func ready(combat, tower: Dictionary, origin: Vector2, stats: Dictionary) -> bool:
	return combat.can_deploy_road_traps(tower, origin, stats)

func attack(combat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	combat.deploy_road_traps(tower, origin, target, stats)
