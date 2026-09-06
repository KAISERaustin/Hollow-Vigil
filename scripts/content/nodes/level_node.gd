extends "res://scripts/content/nodes/content_node.gd"

## Level definitions own layouts; a run owns wave/health/checkpoint progress.
func layout() -> Dictionary:
	var result := attributes()
	result.routes = []
	for road in result.get("roads", []):
		var path: Array[Vector2] = []
		for point in road:
			path.append(Vector2(point[0], point[1]))
		result.routes.append(path)
	return result

func allows_socket(index: int) -> bool:
	return index in _attributes.get("pads", [])
