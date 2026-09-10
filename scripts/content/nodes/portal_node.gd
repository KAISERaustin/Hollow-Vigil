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

func incoming_damage(amount: float, tuning: Dictionary) -> float:
	for attachment in rule("components", []):
		if attachment.slot == "enemy_effects":
			amount = attachment.component.incoming_damage(amount, definition(tuning).merged(attachment.config, true))
	return amount

func advance_enemy(enemy: Dictionary, delta: float, tuning: Dictionary) -> void:
	for attachment in rule("components", []):
		if attachment.slot == "enemy_effects":
			attachment.component.advance(enemy, delta, definition(tuning).merged(attachment.config, true))

func resistance(field: String, tuning: Dictionary) -> float:
	var multiplier := 1.0
	for attachment in rule("components", []):
		if attachment.slot == "enemy_effects":
			multiplier *= attachment.component.resistance(field, definition(tuning).merged(attachment.config, true))
	return multiplier
