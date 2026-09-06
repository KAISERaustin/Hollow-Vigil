extends RefCounted

static func fixture(ids: Array) -> VigilState:
	var g := VigilState.new(20260904)
	g.combat.rng.seed = 20260904
	g.data.balance = 1.0e12
	for id in ids:
		g.expand(id)
	for r in g.data.regions.values():
		r.timer = 1000.0
		r.style = "forest" # Exact route distances use unmodified enemy speeds.
	return g

static func run(suite: SceneTree) -> void:
	# Buy the diagonal before the second approach, so its expansion parent
	# cannot account for the second route. Mirror the user's fork all four ways.
	for x in [-1, 1]:
		for y in [-1, 1]:
			var horizontal := VigilWorld.key(Vector2i(x, 0))
			var vertical := VigilWorld.key(Vector2i(0, y))
			var source := VigilWorld.key(Vector2i(x, y))
			var g := fixture([horizontal, source])
			var existing := g.combat.spawn(source, "basic")
			g.combat.tick(Balance.STEP)
			var original_path: Array = existing.path.duplicate()
			var original_position: Vector2 = existing.pos
			var original_segment: int = existing.segment
			suite.check(g.combat.route_exits[source] == [horizontal], "Unowned alternative is excluded at " + source)
			suite.check(g.expand(vertical), "Unlock second approach to " + source)
			g.data.regions[vertical].timer = 1000.0
			suite.check(existing.path == original_path and existing.pos == original_position and existing.segment == original_segment, "Opening an equal route never changes an enemy in transit")
			var exits: Array = g.combat.route_exits[source]
			suite.check(exits.size() == 2 and horizontal in exits and vertical in exits, "Both equal tile routes are available at " + source)
			var counts := {horizontal: 0, vertical: 0}
			var valid_routes := true
			for kind in Balance.ENEMIES:
				var kind_counts := {horizontal: 0, vertical: 0}
				for i in range(100):
					var enemy := g.combat.spawn(source, kind)
					var via_horizontal: bool = VigilWorld.center(horizontal) in enemy.path
					var via_vertical: bool = VigilWorld.center(vertical) in enemy.path
					valid_routes = valid_routes and via_horizontal != via_vertical
					valid_routes = valid_routes and enemy.path[0] == VigilWorld.center(source) and enemy.path.back() == Vector2.ZERO
					var chosen := horizontal if via_horizontal else vertical
					counts[chosen] += 1
					kind_counts[chosen] += 1
					# Compare the personalized route with the exact drawn spokes.
					var selected := {source: [chosen], chosen: ["0,0"], "0,0": []}
					valid_routes = valid_routes and enemy.path == VigilWorld.route(g.data.regions, source, selected)
				suite.check(kind_counts[horizontal] > 25 and kind_counts[vertical] > 25, "%s uses both equal approaches from %s" % [kind, source])
			suite.check(valid_routes, "Every split route follows connected road geometry to the core from " + source)
			suite.check(counts[horizontal] > 110 and counts[vertical] > 110, "Seeded sample splits reasonably evenly at " + source)
			# Exercise movement for both branches, not just route selection.
			g.combat.tick(Balance.STEP)
			var follows_choice := true
			for enemy in g.combat.enemies:
				if enemy.id == existing.id:
					continue
				var expected := VigilWorld.center(source).move_toward(enemy.path[1], Balance.ENEMIES[enemy.kind].speed * Balance.STEP)
				follows_choice = follows_choice and enemy.pos.is_equal_approx(expected)
			suite.check(follows_choice, "Actual movement follows each enemy's own exit instead of a shared rift route")
			var spawned: int = g.combat.enemy_serial
			for i in range(800):
				g.combat.tick(Balance.STEP)
			suite.check(g.data.escapes == spawned and g.combat.enemies.is_empty(), "Both branches reach the core exactly once without stalls or loops")
			suite.check(g.data.kills == 0 and g.data.lifetime_earnings == 0, "Splitting streams does not duplicate enemies or rewards")
			var reused := g.combat.spawn(source, "basic")
			suite.check(not reused.dead and reused.segment == 1 and reused.pos == VigilWorld.center(source), "Recycled enemy starts its newly chosen route at the rift")

	# A rift with just one exit still needs choices farther downstream.
	var upstream := fixture(["-1,0", "-1,1", "0,1", "-2,1"])
	var used := {}
	for i in range(100):
		var enemy := upstream.combat.spawn("-2,1", "basic")
		used["up" if VigilWorld.center("-1,0") in enemy.path else "right"] = true
	suite.check(upstream.combat.route_exits["-2,1"].size() == 1 and used.size() == 2, "Enemies also split at an equal fork after leaving their source tile")

	# Missing territory forces a real detour; geometric proximity alone is unsafe.
	var detour := fixture(["0,-1", "1,-1", "2,-1", "2,0"])
	var old_enemy := detour.combat.spawn("2,0", "basic")
	var old_path: Array = old_enemy.path.duplicate()
	detour.combat.tick(Balance.STEP)
	var old_position: Vector2 = old_enemy.pos
	suite.check(detour.combat.route_exits["2,0"] == ["2,-1"] and VigilWorld.center("1,0") not in old_path, "A locked direct tile forces enemies along the available detour")
	suite.check(detour.expand("1,0"), "Purchase a shortcut beside an existing rift")
	detour.data.regions["1,0"].timer = 1000.0
	suite.check(old_enemy.path == old_path and old_enemy.pos == old_position, "Shortcut preserves the route and position of an existing enemy")
	suite.check(detour.combat.route_exits["2,0"] == ["1,0"], "Existing rift discovers a shorter non-parent route and excludes the longer detour")
	for i in range(20):
		var enemy := detour.combat.spawn("2,0", "basic")
		suite.check(VigilWorld.center("1,0") in enemy.path and VigilWorld.center("2,-1") not in enemy.path, "New spawns always take the strictly shorter route")
	var spawned: int = detour.combat.enemy_serial
	for i in range(1000):
		detour.combat.tick(Balance.STEP)
	suite.check(detour.data.escapes == spawned and detour.combat.enemies.is_empty(), "Old detour and new shortcut both finish without teleporting or invalid segments")

	# Rebuild derived choices from an ordinary save without adding saved fields.
	upstream.save_path = "user://routing-test.save"
	for r in upstream.data.regions.values():
		r.timer = 0.25
	suite.clean_test_save(upstream.save_path)
	suite.check(upstream.save(1000), "World with split routes saves successfully")
	var loaded := VigilState.new()
	loaded.save_path = upstream.save_path
	suite.check(loaded.load_save(1000) and loaded.combat.route_exits == upstream.combat.route_exits, "Loading reconstructs all shortest routes from existing owned tiles")
	loaded.combat.rng.seed = 20260904
	used.clear()
	for i in range(40):
		var enemy := loaded.combat.spawn("-1,1", "basic")
		used["up" if VigilWorld.center("-1,0") in enemy.path else "right"] = true
	suite.check(used.size() == 2, "A loaded game continues using both equal directions")
	suite.clean_test_save(upstream.save_path)
	print("PASS GROUP: equal routes in four quadrants, downstream forks, unlocked shortcuts, movement, pooling, and saves")
