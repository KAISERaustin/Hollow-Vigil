extends RefCounted

# A broad phase shared by combat and drawing. Exact hit tests stay with callers.
const CELL_SIZE := 128.0
var buckets: Dictionary = {}
var cells: Dictionary = {}
var order: Dictionary = {}
var candidates_checked := 0

func cell_for(pos: Vector2) -> Vector2i:
	return Vector2i((pos / CELL_SIZE).floor())

func rebuild(enemies: Array[Dictionary]) -> void:
	buckets.clear()
	cells.clear()
	order.clear()
	for i in range(enemies.size()):
		var enemy := enemies[i]
		order[enemy.id] = i
		if not enemy.dead:
			insert(enemy)

func insert(enemy: Dictionary) -> void:
	var cell := cell_for(enemy.pos)
	if not buckets.has(cell):
		buckets[cell] = []
	buckets[cell].append(enemy)
	cells[enemy.id] = cell

func moved(enemy: Dictionary) -> void:
	if not cells.has(enemy.id) or cells[enemy.id] == cell_for(enemy.pos):
		return
	var old_cell: Vector2i = cells[enemy.id]
	buckets[old_cell].erase(enemy)
	if buckets[old_cell].is_empty():
		buckets.erase(old_cell)
	insert(enemy)

func query_rect(rect: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var first := cell_for(rect.position)
	var last := cell_for(rect.end)
	candidates_checked = 0
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			for enemy in buckets.get(Vector2i(x, y), []):
				candidates_checked += 1
				# Include the far edge for radius and swept-projectile queries.
				var pos: Vector2 = enemy.pos
				if not enemy.dead and pos.x >= rect.position.x and pos.y >= rect.position.y and pos.x <= rect.end.x and pos.y <= rect.end.y:
					result.append(enemy)
	# Preserve the original enemy order for chain choices, ties and draw overlap.
	result.sort_custom(func(a, b): return order[a.id] < order[b.id])
	return result

func query_radius(pos: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in query_rect(Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		if pos.distance_squared_to(enemy.pos) <= radius * radius:
			result.append(enemy)
	return result
