extends "res://scripts/content/nodes/enemy_node.gd"

## Bosses inherit Enemy identity, health and movement rules plus encounter defenses.
func sound_cue(event: String) -> String:
	return "boss_" + rule("presentation", {}).get("sound_family", _rules.kind) + "_" + event

func create_encounter(serial: int, source: String, position: Vector2, tuning: Dictionary = {}) -> Dictionary:
	var stats := definition(tuning)
	return make_record({"id": serial, "source": source, "kind": _rules.kind,
		"hp": stats.hp, "max_hp": stats.hp, "pos": position, "tile": source,
		"shield": stats.get("shield", 0.0), "wards": int(stats.get("wards", 0)),
		"regen": stats.get("regen_period", 10.0), "toll": stats.get("toll_period", 8.0)})

func movement_speed(enemy: Dictionary, now: float, tuning: Dictionary = {}, resolved: Dictionary = {}) -> float:
	var stats := definition(tuning) if resolved.is_empty() else resolved
	if not Stats.ability_enabled("bosses", _rules.kind, "rage", tuning): return stats.speed
	var capability = preload("res://scripts/content/nodes/enemy_capability.gd").new("rage", null, {}, {"behavior": "rage"})
	var slow: float = enemy.get("slow_percent", 0.0) * (1.0 - stats.get("ice_resistance", 0.0) / 100.0) if enemy.get("slow_until", 0.0) > now else 0.0
	return stats.speed * capability.speed(enemy, now, stats, slow)

func absorb_damage(enemy: Dictionary, amount: float, branch: String, fire: bool, tuning: Dictionary = {}, pierce: bool = false) -> float:
	var stats := definition(tuning)
	for ability in ["rage", "wards", "shield"]:
		if not Stats.ability_enabled("bosses", _rules.kind, ability, tuning): continue
		var capability = preload("res://scripts/content/nodes/enemy_capability.gd").new(ability, null, {}, {"behavior": ability})
		amount = capability.absorb(enemy, amount, [branch], fire, pierce, stats)
	return amount
