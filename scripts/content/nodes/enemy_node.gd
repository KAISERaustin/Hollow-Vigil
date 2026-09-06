extends "res://scripts/content/nodes/content_node.gd"

## One constructor resets reused records for all ordinary enemy subtypes.
func create_into(record: Dictionary, serial: int, source: String, route: Array[Vector2], style: String, tuning: Dictionary = {}, health_multiplier: float = 1.0) -> Dictionary:
	record.clear()
	record.merge(make_record({"id": serial, "source": source, "kind": _rules.kind, "rift_style": style}))
	record.hp = definition(tuning).hp * health_multiplier
	record.max_hp = record.hp
	# Routes are immutable shared geometry, never copied per enemy.
	record.path = route
	record.pos = route[0]
	return record

func escape_damage() -> int:
	return int(_rules.get("escape_damage", 1))
