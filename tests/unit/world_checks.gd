extends RefCounted

static func run(suite: SceneTree) -> void:
	test_world(suite)
	test_territory_styles(suite)

static func test_world(suite: SceneTree) -> void:
	var g := VigilState.new(4242)
	g.data.balance = 1.0e12
	var root_road := VigilWorld.spoke(g.data.regions["0,0"], 1)
	var first_path: Array = g.paths["0,0"].duplicate()
	var first_pad := VigilWorld.pad_position("0,0", 0)
	var directions := {}
	for i in range(80):
		var options := VigilWorld.frontier(g.data.regions, int(g.data.seed))
		var id: String = options.keys()[i % options.size()]
		suite.check(g.expand(id), "Expansion %d purchases successfully" % i)
		var r: Dictionary = g.data.regions[id]
		directions[r.side] = true
		var path: Array = g.paths[id]
		suite.check(path[0] == VigilWorld.center(id), "Expansion %d rift starts at its tile center" % i)
		for kind in (Balance.DUNGEON_KINDS if r.style == "castle_ruin" else Balance.NORMAL_KINDS):
			var spawned := g.combat.spawn(id, kind)
			suite.check(spawned.pos == VigilWorld.center(id), "Expansion %d spawns %s at its tile center" % [i, kind])
		suite.check(path.size() > 2 and path[-1] == Vector2.ZERO, "Expansion %d reaches the central core" % i)
		var connected := true
		for j in range(path.size() - 1):
			if path[j].distance_to(path[j + 1]) > 151:
				connected = false
		suite.check(connected, "Expansion %d has no road gaps" % i)
		var backtracks := false
		for j in range(1, path.size() - 1):
			var incoming: Vector2 = path[j] - path[j - 1]
			var outgoing: Vector2 = path[j + 1] - path[j]
			if is_zero_approx(incoming.cross(outgoing)) and incoming.dot(outgoing) < 0.0:
				backtracks = true
		suite.check(not backtracks, "Expansion %d never doubles back at a road junction" % i)
	suite.check(directions.size() == 4, "Procedural entrances originate from all four directions")
	suite.check(root_road == VigilWorld.spoke(g.data.regions["0,0"], 1) and first_path == g.paths["0,0"] and first_pad == VigilWorld.pad_position("0,0", 0), "Expansion preserves roads, routes, and tower positions")
	suite.check(not g.expand("0,0") and not g.expand("999,999"), "Existing and disconnected expansion requests are rejected")
	var twin := VigilState.new(4242)
	suite.check(twin.data.regions["0,0"].bend == g.data.regions["0,0"].bend, "Seeded terrain reproduces")
	print("PASS GROUP: 80 connected, stable expansions")

static func test_territory_styles(suite: SceneTree) -> void:
	var g := VigilState.new(879)
	g.data.balance = 1.0e12
	var seen := {}
	suite.check(g.data.regions["0,0"].style == "forest", "Starting territory retains forest")
	for i in range(1, 61):
		var id: String = VigilWorld.frontier(g.data.regions, int(g.data.seed)).keys()[i % VigilWorld.frontier(g.data.regions, int(g.data.seed)).size()]
		suite.check(g.expand(id), "Styled territory can be claimed")
		var style: String = g.data.regions[id].style
		suite.check(style in VigilWorld.STYLES or style == "castle_ruin", "New territory selects a supported theme")
		seen[style] = true
	suite.check(seen.has("forest") and seen.has("castle_ruin") and seen.size() == 5, "Purchased territories include all four biomes and castle ruins")
	var before: Dictionary = g.data.regions.duplicate(true)
	suite.check(not g.expand("0,0") and g.data.regions == before, "Failed claim cannot reroll existing styles")
	g.save_path = "user://territory-style-test.save"
	suite.clean_test_save(g.save_path)
	suite.check(g.save(1000), "Styled world saves")
	var loaded := VigilState.new()
	loaded.save_path = g.save_path
	suite.check(loaded.load_save(1000), "Styled world loads")
	for id in g.data.regions:
		suite.check(loaded.data.regions[id].style == g.data.regions[id].style, "Saved territory keeps its selected theme")
	for r in g.data.regions.values():
		r.erase("style")
	suite.check(g.save(1000) and loaded.load_save(1000), "Legacy world without styles still loads")
	for r in loaded.data.regions.values():
		suite.check(r.style == "forest", "Legacy territories preserve forest appearance")
	loaded.data.regions["0,0"].style = "unknown"
	suite.check(not loaded.storage.valid_data(loaded.data), "Unknown saved style is rejected")
	suite.clean_test_save(g.save_path)
	print("PASS GROUP: territory theme selection, persistence and legacy saves")
