extends RefCounted

# One separated, connected ruin per sector, generated on demand.
# This independent stream never consumes combat or economy randomness.
const SECTOR_SIZE := 7
static var cluster_cache: Dictionary = {}

static func cluster(sector: Vector2i, seed_value: int) -> Array[Vector2i]:
	var cache_key := str(sector) + ":" + str(seed_value)
	if cluster_cache.has(cache_key):
		return cluster_cache[cache_key]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("hidden-area:" + str(sector) + ":" + str(seed_value)).hash())
	var origin := sector * SECTOR_SIZE - Vector2i(3, 3)
	var available: Array[Vector2i] = []
	for y in range(1, SECTOR_SIZE - 1):
		for x in range(1, SECTOR_SIZE - 1):
			var cell := origin + Vector2i(x, y)
			# Leave the core and its first expansion choices clear.
			if maxi(absi(cell.x), absi(cell.y)) > 1:
				available.append(cell)
	var result: Array[Vector2i] = [available[rng.randi_range(0, available.size() - 1)]]
	var count := rng.randi_range(4, 5)
	while result.size() < count:
		var frontier: Array[Vector2i] = []
		for cell in result:
			for direction in VigilWorld.DIRS:
				var neighbor: Vector2i = cell + direction
				if available.has(neighbor) and not result.has(neighbor) and not frontier.has(neighbor):
					frontier.append(neighbor)
		result.append(frontier[rng.randi_range(0, frontier.size() - 1)])
	if cluster_cache.size() >= 2048:
		cluster_cache.clear()
	cluster_cache[cache_key] = result
	return result

static func sector_for(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x + 3) / SECTOR_SIZE), floori(float(cell.y + 3) / SECTOR_SIZE))

static func preserved(sector: Vector2i, seed_value: int, regions: Dictionary) -> bool:
	# Never replace purchased terrain, towers, or legacy encounters.
	for cell in cluster(sector, seed_value):
		if regions.has(VigilWorld.key(cell)):
			return true
	return false

static func reserved(cell: Vector2i, seed_value: int, regions: Dictionary) -> bool:
	var sector := sector_for(cell)
	return cluster(sector, seed_value).has(cell) and not regions.has(VigilWorld.key(cell))

static func gate(sector: Vector2i, seed_value: int) -> Dictionary:
	var cells := cluster(sector, seed_value)
	# Prefer the original encounter tile; a surrounded center uses the next
	# boundary tile. The choice depends only on seed, never purchase order.
	for cell in cells:
		var sides: Array[int] = []
		for side in range(4):
			if not cells.has(cell + VigilWorld.DIRS[side]):
				sides.append(side)
		if not sides.is_empty():
			var side: int = sides[absi(("castle-gate:" + str(sector) + str(seed_value)).hash()) % sides.size()]
			return {"id": VigilWorld.key(cell), "side": side, "neighbor": VigilWorld.key(cell + VigilWorld.DIRS[side])}
	return {}

static func emergence(g: Dictionary, regions: Dictionary) -> Array[Vector2]:
	var outward := Vector2(VigilWorld.DIRS[int(g.side)])
	var edge := VigilWorld.center(g.id) + outward * Balance.TILE * 0.5
	var path: Array[Vector2] = [edge - outward * 65.0, edge - outward * 32.0, edge]
	path.append_array(VigilWorld.spoke(regions[g.neighbor], (int(g.side) + 2) % 4).slice(1))
	return path
