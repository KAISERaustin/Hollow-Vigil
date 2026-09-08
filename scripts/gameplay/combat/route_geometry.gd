extends RefCounted

## Immutable route snapshot. Live actors own references, never saved cache data.
var points: Array[Vector2] = []
var suffix := PackedFloat64Array()

func _init(route: Array) -> void:
	points.assign(route)
	points.make_read_only()
	suffix.resize(points.size())
	for index in range(points.size() - 2, -1, -1):
		suffix[index] = suffix[index + 1] + points[index].distance_to(points[index + 1])

func remaining(position: Vector2, segment: int) -> float:
	return position.distance_to(points[segment]) + suffix[segment]
