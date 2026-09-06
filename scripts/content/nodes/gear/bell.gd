extends "res://scripts/content/nodes/gear_node.gd"

func _apply_attack(progress: Dictionary, _target_id: int, _now: float, stats: Dictionary, gear: Dictionary) -> void:
	stats.relic_echo = int(progress.attacks) % int(gear.attack_count) == 0
