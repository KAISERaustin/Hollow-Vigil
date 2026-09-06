extends "res://scripts/content/nodes/content_node.gd"

const ContentNode = preload("res://scripts/content/nodes/content_node.gd")

func can_equip_on(target: ContentNode) -> bool:
	return target != null and target.is_a(_rules.get("equipped_on", "tower")) and _rules.slot in target.rule("equipment_slots", [])

func prepare(progress: Dictionary, target_id: int, now: float, stats: Dictionary, tuning: Dictionary = {}) -> Dictionary:
	var result := stats.duplicate()
	progress.attacks += 1
	_apply_attack(progress, target_id, now, result, definition(tuning))
	progress.target = target_id
	progress.last = now
	return result

func _apply_attack(_progress: Dictionary, _target_id: int, _now: float, _stats: Dictionary, _gear: Dictionary) -> void:
	pass
