extends "res://scripts/content/nodes/content_node.gd"

# Stateless presentation component. Owners pass current instance state on every
# draw; removing/replacing this attachment cannot leave stale upgrades behind.
func parts(level: int, inhabitants: Array, config: Dictionary) -> Dictionary:
	var structural: Array = rule("rate_parts", [])
	var rate := clampi(level, 0, int(rule("max_level", 12)))
	var ornaments: Array = []
	var assignments: Dictionary = config.get("ornaments", {})
	var mounts: Array = config.get("mounts", [])
	var order: Array = config.get("order", [])
	for index in range(order.size()):
		var kind: String = order[index]
		if kind in inhabitants and assignments.has(kind) and index < mounts.size():
			ornaments.append(assignments[kind].merged({"kind": kind, "at": mounts[index]}))
	return {"structure": structural.slice(0, mini(rate, structural.size())), "runes": maxi(0, rate - structural.size()), "ornaments": ornaments}
