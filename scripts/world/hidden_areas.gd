extends RefCounted

# One separated, connected placeholder per sector, generated on demand.
# This independent stream never consumes combat or economy randomness.
const SECTOR_SIZE := 7

static func cluster(sector: Vector2i, seed_value: int) -> Array[Vector2i]:
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
	return result

static func sector_for(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x + 3) / SECTOR_SIZE), floori(float(cell.y + 3) / SECTOR_SIZE))
