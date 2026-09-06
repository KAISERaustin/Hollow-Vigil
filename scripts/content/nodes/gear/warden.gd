extends "res://scripts/content/nodes/gear_node.gd"

func _apply_attack(progress: Dictionary, _target_id: int, now: float, stats: Dictionary, gear: Dictionary) -> void:
	if now >= progress.root_ready:
		stats.relic_root = true
		progress.root_ready = now + gear.root_period
