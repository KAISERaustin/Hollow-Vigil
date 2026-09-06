extends RefCounted

# Each 5x5 cell contains two connected patches. Adjacent cells use disjoint
# palette pairs, so patches cannot merge across cell edges. Diagonals may touch.
const CELL_SIZE := 5
const CACHE_LIMIT := 256
static var _cache: Dictionary = {}

static func style_index(tile: Vector2i, world_seed: int) -> int:
	var cell := Vector2i(floori(tile.x / float(CELL_SIZE)), floori(tile.y / float(CELL_SIZE)))
	var cache_key := "%d:%d:%d" % [world_seed, cell.x, cell.y]
	if not _cache.has(cache_key):
		if _cache.size() >= CACHE_LIMIT:
			_cache.clear()
		_cache[cache_key] = _make_cell(cell, world_seed)
	var local := tile - cell * CELL_SIZE
	return _cache[cache_key][local.y * CELL_SIZE + local.x]

static func _make_cell(cell: Vector2i, world_seed: int) -> PackedInt32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("terrain-cluster:%d:%d:%d" % [world_seed, cell.x, cell.y]).hash())
	# Sum of two uniform rolls gives triangular weights: 12 is eight times as
	# likely as 5. The complementary patch peaks at 13; together sizes span 5-20.
	var target := 5 + rng.randi_range(0, 7) + rng.randi_range(0, 7)
	var heights := [1, 1, 1, 1, 1]
	for unused in range(target - 5):
		var available: Array[int] = []
		for column in range(CELL_SIZE):
			if heights[column] < 4:
				available.append(column)
		heights[available[rng.randi_range(0, available.size() - 1)]] += 1
	var rotation := rng.randi_range(0, 3)
	var patches := PackedInt32Array()
	patches.resize(CELL_SIZE * CELL_SIZE)
	for y in range(CELL_SIZE):
		for x in range(CELL_SIZE):
			var point := Vector2i(x, y)
			for turn in range(rotation):
				point = Vector2i(CELL_SIZE - 1 - point.y, point.x)
			patches[point.y * CELL_SIZE + point.x] = 0 if y < heights[x] else 1
	# Seeded palette permutation keeps all four themes represented, while the
	# origin's patch is forest to match the starting territory without a hole.
	var palette_rng := RandomNumberGenerator.new()
	palette_rng.seed = absi(("terrain-palette:" + str(world_seed)).hash())
	var palette := [0, 1, 2, 3]
	for i in range(3, 1, -1):
		var j := palette_rng.randi_range(1, i)
		var temporary: int = palette[i]
		palette[i] = palette[j]
		palette[j] = temporary
	var pair := posmod(cell.x + cell.y, 2) * 2
	var flip := patches[0] if cell == Vector2i.ZERO else rng.randi_range(0, 1)
	for i in range(patches.size()):
		patches[i] = palette[pair + (patches[i] ^ flip)]
	return patches
