extends "res://scripts/content/nodes/content_node.gd"
## Reusable selection category. Definitions are immutable; form choices belong to the view.

func types() -> Array:
	var category: String = rule("category", "")
	if category.is_empty(): return []
	var kinds := Balance.definitions(category).keys()
	return kinds.filter(func(kind): return Balance.Content.tower(kind) != null) if category == "towers" else kinds

func capture(tuning: Dictionary, selected: Array) -> Dictionary:
	var category: String = rule("category", "")
	var result := {}
	for kind in Balance.definitions(category):
		if kind.get_slice(":", 0) not in selected: continue
		var values := {}
		for stat in Balance.editable_fields_for(category, kind):
			values[stat] = Balance.configuration_value(category, kind, stat, tuning)
		result[kind] = values
	return result
