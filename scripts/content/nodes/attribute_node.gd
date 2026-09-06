extends "res://scripts/content/nodes/content_node.gd"

## Immutable, attachable behavior. All mutable state is supplied by its owner.
func prepare(_state: Dictionary, _context: Dictionary, _stats: Dictionary, _config: Dictionary) -> void:
	pass

func impact(_combat, _shot: Dictionary, _enemy: Dictionary, _config: Dictionary) -> void:
	pass

func retune(_state: Dictionary, _now: float, _before: Dictionary, _after: Dictionary) -> void:
	pass

func active(context: Dictionary, config: Dictionary) -> bool:
	return int(context.attacks) % maxi(1, int(config.get("attack_count", 1))) == 0

func effect(stats: Dictionary, config: Dictionary) -> void:
	stats.gear_effects.append({"attribute": self, "config": config.duplicate(true)})
