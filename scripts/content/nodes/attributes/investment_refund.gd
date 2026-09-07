extends "res://scripts/content/nodes/attribute_node.gd"

## The owning economy attaches this only while its refund window is open.
func sale_refund(tower: Dictionary, tuning: Dictionary, _current: float, config: Dictionary) -> float:
	return Balance.invested_cost(tower, tuning) * clampf(float(config.get("ratio", 1.0)), 0.0, 1.0)
