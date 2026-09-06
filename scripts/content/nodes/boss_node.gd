extends "res://scripts/content/nodes/enemy_node.gd"

## Bosses inherit Enemy identity, health and movement rules plus encounter defenses.
func create_encounter(serial: int, source: String, position: Vector2, tuning: Dictionary = {}) -> Dictionary:
	var stats := definition(tuning)
	return make_record({"id": serial, "source": source, "kind": _rules.kind,
		"hp": stats.hp, "max_hp": stats.hp, "pos": position, "tile": source,
		"shield": stats.get("shield", 0.0), "wards": int(stats.get("wards", 0)),
		"regen": stats.get("regen_period", 10.0), "toll": stats.get("toll_period", 8.0)})

func movement_speed(_enemy: Dictionary, _now: float, tuning: Dictionary = {}) -> float:
	return definition(tuning).speed

func absorb_damage(_enemy: Dictionary, amount: float, _branch: String, _fire: bool, _tuning: Dictionary = {}, _pierce: bool = false) -> float:
	return amount
