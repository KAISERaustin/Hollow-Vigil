extends "res://scripts/content/nodes/attribute_node.gd"

func returning() -> bool:
	return id == "attribute/returning_attack" or rule("returning", false)

func ready(combat, tower: Dictionary, _origin: Vector2, _stats: Dictionary) -> bool:
	if returning():
		for shot in combat.line_projectiles:
			if shot.tower_id == tower.id and shot.returning: return false
	return true

func attack(combat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	preload("res://scripts/gameplay/combat/line_projectiles.gd").launch(combat, tower, origin, target, stats, returning())
