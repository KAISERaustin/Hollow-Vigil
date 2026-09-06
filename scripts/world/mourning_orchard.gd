extends RefCounted

# Exactly one connected patch per seed, independent of expansion/combat RNG.
# A bounded ring keeps it discoverable; ruins and the opening remain untouched.
const STYLE := "mourning_orchard"
static var cache: Dictionary = {}

static func cluster(seed_value: int) -> Array[Vector2i]:
	if cache.has(seed_value):
		return cache[seed_value]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("mourning-orchard:" + str(seed_value)).hash())
	var available: Array[Vector2i] = []
	for y in range(-9, 10):
		for x in range(-9, 10):
			var cell := Vector2i(x, y)
			if maxi(absi(x), absi(y)) >= 3 and not VigilWorld.is_ruin(VigilWorld.key(cell), seed_value):
				available.append(cell)
	var count := rng.randi_range(6, 9)
	var result: Array[Vector2i] = []
	# Retry isolated starts, without changing the eligible terrain or ruin layout.
	while not available.is_empty():
		var start := available[rng.randi_range(0, available.size() - 1)]
		result = [start]
		while result.size() < count:
			var frontier: Array[Vector2i] = []
			for cell in result:
				for direction in VigilWorld.DIRS:
					var next: Vector2i = cell + direction
					if available.has(next) and not result.has(next) and not frontier.has(next):
						frontier.append(next)
			if frontier.is_empty():
				break
			result.append(frontier[rng.randi_range(0, frontier.size() - 1)])
		if result.size() == count:
			break
		for cell in result:
			available.erase(cell)
	if cache.size() >= 256:
		cache.clear()
	cache[seed_value] = result
	return result

static func gate(seed_value: int) -> String:
	return VigilWorld.key(cluster(seed_value)[0])
