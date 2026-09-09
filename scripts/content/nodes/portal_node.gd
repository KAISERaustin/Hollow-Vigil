extends "res://scripts/content/nodes/content_node.gd"

func visual_parts(level: int, unlocks: Array) -> Dictionary:
	for attachment in rule("components", []):
		if attachment.slot == "appearance":
			return attachment.component.parts(level, available_kinds(unlocks), attachment.config)
	return {"structure": [], "runes": 0, "ornaments": []}

func enemy_kinds() -> Array:
	return rule("enemy_kinds", [])

func available_kinds(inhabitants: Array) -> Array:
	var initial: Array = rule("initial_ornaments", [])
	return enemy_kinds().filter(func(kind): return kind in initial or kind in inhabitants)

func accepts(kind: String) -> bool:
	return kind in _rules.get("enemy_kinds", [])
