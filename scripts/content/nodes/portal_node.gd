extends "res://scripts/content/nodes/content_node.gd"

func enemy_kinds() -> Array:
	return rule("enemy_kinds", [])

func unlock_costs() -> Dictionary:
	var costs: Dictionary = rule("unlock_costs", {})
	var result := {}
	for kind in enemy_kinds():
		if costs.has(kind):
			result[kind] = costs[kind]
	return result

func available_kinds(unlocks: Array) -> Array:
	var costs := unlock_costs()
	var result: Array = []
	for kind in enemy_kinds():
		if not costs.has(kind) or kind in unlocks:
			result.append(kind)
	return result

func is_exclusive() -> bool:
	return bool(_rules.get("exclusive", false))

func accepts(kind: String) -> bool:
	return kind in _rules.get("enemy_kinds", [])
