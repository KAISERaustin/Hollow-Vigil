extends RefCounted

static func populate(game: VigilState) -> String:
	var gate := VigilWorld.Orchard.gate(int(game.data.seed))
	var target := VigilWorld.coord(gate)
	var cursor := Vector2i.ZERO
	# Connected roads to the real seeded entrance, without consuming player gold.
	while cursor != target:
		var previous := VigilWorld.key(cursor)
		cursor += Vector2i(signi(target.x - cursor.x), 0) if cursor.x != target.x else Vector2i(0, signi(target.y - cursor.y))
		var id := VigilWorld.key(cursor)
		if not game.data.regions.has(id):
			game.data.regions[id] = VigilWorld.make_region(id, previous, int(game.data.seed))
		game.data.regions[id].timer = 9.0
	for cell in VigilWorld.Orchard.cluster(int(game.data.seed)):
		var id := VigilWorld.key(cell)
		if not game.data.regions.has(id):
			var parent := ""
			for direction in VigilWorld.DIRS:
				var neighbor := VigilWorld.key(cell + direction)
				if game.data.regions.has(neighbor):
					parent = neighbor
					break
			game.data.regions[id] = VigilWorld.make_region(id, parent, int(game.data.seed))
		game.data.regions[id].style = "mourning_orchard"
		game.data.regions[id].timer = 9.0
	game.data.first_property_required = false
	game.refresh_paths()
	return gate
