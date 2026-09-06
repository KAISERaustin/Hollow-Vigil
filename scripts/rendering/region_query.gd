extends RefCounted

# Region keys form a regular lattice: enumerate the viewport, not the world.
static func in_view(regions: Dictionary, view: Rect2, padding: float = 0.0) -> Array[String]:
	var bounds := view.grow(padding)
	var first := Vector2i((bounds.position / Balance.TILE).ceil())
	var last := Vector2i((bounds.end / Balance.TILE).floor())
	var result: Array[String] = []
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var id := VigilWorld.key(Vector2i(x, y))
			if regions.has(id):
				result.append(id)
	return result
