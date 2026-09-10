extends "res://scripts/content/nodes/content_node.gd"

func schedule() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var groups: Array = _attributes.get("groups", [])
	for group_index in groups.size():
		var group: Array = groups[group_index]
		for count in range(int(group[1])):
			result.append({"kind": group[0], "lane": int(group[2]), "at": float(group[3]) + count * float(group[4]), "order": result.size(), "group": group_index, "member": count})
			if group.size() == 6: result[-1].payout = float(group[5])
	result.sort_custom(func(a, b): return a.at < b.at if a.at != b.at else a.order < b.order)
	return result
