extends "res://scripts/content/nodes/content_node.gd"

func schedule() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group in _attributes.get("groups", []):
		for count in range(int(group[1])):
			result.append({"kind": group[0], "lane": int(group[2]), "at": float(group[3]) + count * float(group[4]), "order": result.size()})
	result.sort_custom(func(a, b): return a.at < b.at if a.at != b.at else a.order < b.order)
	return result
