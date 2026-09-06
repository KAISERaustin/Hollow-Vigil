extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, _context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	effect(stats, config)

func impact(combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	var applies := false
	match rule("condition"):
		"boss": applies = enemy.get("boss", false)
		"healthy": applies = enemy.hp / enemy.max_hp * 100.0 >= config.health_threshold
		"wounded": applies = enemy.hp / enemy.max_hp * 100.0 <= config.health_threshold
		"hindered": applies = combat.Relics.hindered(enemy, combat.simulation_time)
	if applies:
		shot.damage *= config.damage_multiplier
