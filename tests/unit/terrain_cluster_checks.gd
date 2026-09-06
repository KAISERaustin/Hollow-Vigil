extends RefCounted

static func run(suite: SceneTree) -> void:
	var generator = preload("res://scripts/world/terrain_clusters.gd")
	var histogram := {}
	var signatures := {}
	for seed_value in [0, 1, 879, 42178]:
		var tiles := {}
		var signature := ""
		for y in range(-25, 25):
			for x in range(-25, 25):
				var point := Vector2i(x, y)
				var style: int = generator.style_index(point, seed_value)
				tiles[point] = style
				signature += str(style)
		signatures[signature] = true
		suite.check(generator.style_index(Vector2i.ZERO, seed_value) == 0, "Starting tile belongs to a forest cluster")
		var visited := {}
		var valid_sizes := true
		var themes := {}
		for start in tiles:
			if visited.has(start):
				continue
			var queue: Array[Vector2i] = [start]
			visited[start] = true
			var head := 0
			while head < queue.size():
				var point := queue[head]
				head += 1
				for direction in VigilWorld.DIRS:
					var neighbor: Vector2i = point + direction
					if tiles.has(neighbor) and not visited.has(neighbor) and tiles[neighbor] == tiles[start]:
						visited[neighbor] = true
						queue.append(neighbor)
			valid_sizes = valid_sizes and queue.size() >= 5 and queue.size() <= 20
			histogram[queue.size()] = histogram.get(queue.size(), 0) + 1
			themes[tiles[start]] = true
		suite.check(valid_sizes, "Every complete edge-connected cluster contains 5-20 tiles, including across cell boundaries")
		suite.check(themes.size() == 4, "Clustered worlds include every terrain theme")
		# Force cache eviction, then request the same world in reverse order.
		for x in range(300):
			generator.style_index(Vector2i(x * 5, 1000), seed_value + 1)
		var stable := true
		var points: Array = tiles.keys()
		points.reverse()
		for point in points:
			stable = stable and generator.style_index(point, seed_value) == tiles[point]
		suite.check(stable, "Seeded clusters survive eviction and do not depend on exploration order")
		suite.check(VigilWorld.region_style("-7,11", seed_value) == VigilWorld.STYLES[tiles[Vector2i(-7, 11)]], "World generation uses clustered terrain at negative coordinates")
	suite.check(signatures.size() == 4, "Different world seeds produce different terrain layouts")
	suite.check(histogram.get(12, 0) > histogram.get(5, 0) * 3 and histogram.get(13, 0) > histogram.get(20, 0) * 3, "Cluster sizes strongly favor 12-13 over the extremes")
	print("PASS GROUP: seeded terrain clusters; size histogram ", histogram)
