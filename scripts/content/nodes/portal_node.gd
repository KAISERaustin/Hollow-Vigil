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

func spawn_mix(unlocks: Array) -> Dictionary:
	var available := available_kinds(unlocks)
	var mix := {}
	if available.is_empty():
		return mix
	var shares: Dictionary = rule("shares", {})
	if shares.is_empty():
		for kind in available:
			mix[kind] = 1.0 / available.size()
	else:
		var remaining := 1.0
		for kind in available.slice(1):
			mix[kind] = float(shares.get(kind, 0.0))
			remaining -= mix[kind]
		mix[available[0]] = maxf(0.0, remaining)
	return mix

func choose_kind(unlocks: Array, roll: float) -> String:
	var mix := spawn_mix(unlocks)
	var cumulative := 0.0
	for kind in mix:
		cumulative += mix[kind]
		if roll < cumulative:
			return kind
	return "" if mix.is_empty() else str(mix.keys()[-1])

func saved_unlock_costs() -> Dictionary:
	return rule("legacy_costs", {}).merged(unlock_costs(), true)

func retired_unlock_refund(unlocks: Array) -> float:
	var current := unlock_costs()
	var old: Dictionary = rule("legacy_costs", {})
	var refund := 0.0
	for kind in unlocks:
		if not current.has(kind):
			refund += float(old.get(kind, 0.0))
	return refund
