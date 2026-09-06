extends "res://scripts/content/nodes/content_node.gd"

func boss_kind() -> String:
	return rule("boss", "")

func create(region_id: String, parent_id: String, side: int, bend: float) -> Dictionary:
	return make_record({"id": region_id, "parent": parent_id, "style": _rules.kind, "side": side, "bend": bend})
