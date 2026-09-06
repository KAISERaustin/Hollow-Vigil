extends RefCounted

const Areas = preload("res://scripts/world/hidden_areas.gd")

static func run(suite: SceneTree) -> void:
	for seed_value in [1, 879, 45678]:
		var occupied := {}
		for y in range(-3, 4):
			for x in range(-3, 4):
				var sector := Vector2i(x, y)
				var cells := Areas.cluster(sector, seed_value)
				suite.check(cells.size() in [4, 5], "Hidden clusters contain four or five tiles")
				suite.check(cells == Areas.cluster(sector, seed_value), "Hidden placement is stable for a world seed")
				var visited: Array[Vector2i] = [cells[0]]
				for cell in visited:
					for direction in VigilWorld.DIRS:
						var neighbor: Vector2i = cell + direction
						if cells.has(neighbor) and not visited.has(neighbor):
							visited.append(neighbor)
				suite.check(visited.size() == cells.size(), "Every hidden cluster is edge-connected")
				for cell in cells:
					suite.check(Areas.sector_for(cell) == sector and not occupied.has(cell), "Hidden tiles stay in their sector without overlap")
					suite.check(maxi(absi(cell.x), absi(cell.y)) > 1, "Hidden areas leave starter choices clear")
					for direction in VigilWorld.DIRS:
						suite.check(not occupied.has(cell + direction) or occupied[cell + direction] == sector, "Separate clusters never touch")
					occupied[cell] = sector
	var game := VigilState.new(879)
	var layer := preload("res://scripts/rendering/hidden_areas.gd").new()
	var snapshot := game.data.duplicate(true)
	var view := Rect2(-3000, -3000, 6000, 6000)
	layer.synchronize(game, view)
	suite.check(game.data == snapshot, "Placeholder preview never changes progression or saves")
	var claimed := layer.cells[0]
	game.data.regions[VigilWorld.key(claimed)] = VigilWorld.make_region(VigilWorld.key(claimed), "", 879)
	game.terrain_revision += 1
	layer.synchronize(game, view)
	suite.check(not layer.cells.has(claimed), "Owned terrain replaces its stone placeholder")
	layer.free()
