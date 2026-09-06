extends "res://scripts/content/nodes/gear_node.gd"

func _apply_attack(progress: Dictionary, target_id: int, now: float, stats: Dictionary, gear: Dictionary) -> void:
	progress.stacks = mini(int(gear.stack_limit), int(progress.stacks) + 1) if progress.target == target_id and now - progress.last < gear.stack_timeout else 0
	stats.period /= 1.0 + progress.stacks * gear.speed_per_stack / 100.0
