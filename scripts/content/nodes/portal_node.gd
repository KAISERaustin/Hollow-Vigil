extends "res://scripts/content/nodes/content_node.gd"

func enemy_kinds() -> Array:
	return rule("enemy_kinds", [])

func is_exclusive() -> bool:
	return bool(_rules.get("exclusive", false))

func accepts(kind: String) -> bool:
	return kind in _rules.get("enemy_kinds", [])
