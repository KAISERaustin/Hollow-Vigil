extends RefCounted

const Bosses = preload("res://scripts/gameplay/encounters/bosses.gd")
const Areas = preload("res://scripts/world/hidden_areas.gd")

static func fixture(kind: String) -> VigilState:
	var game := VigilState.new(879)
	game.data.balance = 1.0e30
	game.data.first_property_required = false
	var target := Vector2i.ZERO
	for y in range(-24,25):
		for x in range(-24,25):
			var cell := Vector2i(x,y)
			if abs(x) + abs(y) < 2:
				continue
			if Bosses.Clusters.at(VigilWorld.key(cell), 879).boss_tile != VigilWorld.key(cell):
				continue
			if Bosses.kind_at(VigilWorld.key(cell),879) == kind and (target == Vector2i.ZERO or Vector2(cell).length() < Vector2(target).length()):
				target = cell
	var cursor := Vector2i.ZERO
	while cursor != target:
		var previous := cursor
		if cursor.x != target.x:
			cursor.x += 1 if target.x > cursor.x else -1
		else:
			cursor.y += 1 if target.y > cursor.y else -1
		var id := VigilWorld.key(cursor)
		game.data.regions[id] = VigilWorld.make_region(id,VigilWorld.key(previous),879)
	game.refresh_paths()
	Bosses.awaken(game.combat,VigilWorld.key(target))
	return game

static func shot(id: String, branch: String, amount: float = 100.0) -> Dictionary:
	return {"tower_id":id,"branch":branch,"damage":amount}

static func run(suite: SceneTree) -> void:
	var kinds := {}
	for style in VigilWorld.ALL_STYLES:
		var kind := Balance.Content.region(style).boss_kind()
		suite.check(Balance.BOSSES.has(kind) and not kinds.has(kind), "Every biome has a distinct registered boss: " + style)
		kinds[kind] = true
		suite.check(Bosses.kind_at("1,0", 879, style) == kind, "Saved tile style selects its biome boss")
	suite.check(kinds.size() == 6 and Bosses.kind_at("0,0",879) == "", "Six biome bosses with no starting-core encounter")
	legacy_encounters(suite)
	for kind in Bosses.TYPES:
		for event in ["awaken", "step", "death", "escape"]:
			var cue := Balance.Content.boss(kind).sound_cue(event)
			suite.check(preload("res://assets/audio/catalog.json").data.has(cue) and ResourceLoader.exists("res://assets/audio/" + cue + ".wav"), "Boss presentation assigns an available sound: " + kind + "/" + event)
		var game := fixture(kind)
		var e: Dictionary = game.combat.enemies[0]
		var source: String = e.source
		Bosses.awaken(game.combat,source)
		suite.check(game.combat.enemies.size() == 1,"Repeated unlock cannot duplicate a boss")
		# Existing owned encounters keep the legacy center-to-road behavior.
		game.data.regions[source].erase("boss")
		game.combat.enemies.clear()
		game.refresh_paths()
		Bosses.awaken(game.combat, source)
		suite.check(game.combat.enemies.size() == 1,"Legacy owned boss tile summons exactly one boss")
		e = game.combat.enemies[0]
		for r in game.data.regions.values():
			r.timer = 9.0
		var original_leg: Array = e.path.duplicate()
		var frontier := VigilWorld.frontier(game.data.regions, int(game.data.seed))
		game.expand(frontier.keys()[0])
		suite.check(e.path == original_leg,"Expansion preserves an existing patrol leg")
		# Exercise junction transitions while keeping the core out of patrols.
		for crossing in range(20):
			e.pos = e.path[-1]
			e.segment = e.path.size()-1
			var previous_steps: int = e.steps
			game.combat.tick(0.05)
			suite.check(not e.dead and e.steps == previous_steps+1,"Combat tick continues boss patrol instead of escaping")
		var seen := {}
		for crossing in range(40):
			var path: Array = e.path
			suite.check(path[0] == VigilWorld.center(e.previous) and path[-1] == VigilWorld.center(e.tile),"Patrol connects owned tile centers")
			for i in range(1,path.size()):
				suite.check(path[i].distance_to(path[i-1]) < 80.0,"Patrol follows sampled roads without teleportation")
			seen[e.tile] = true
			e.pos = path[-1]
			Bosses.next_leg(game.combat,e)
		suite.check(not seen.has("0,0") and seen.size() > 1 and not e.dead,"Boss wanders and backtracks without visiting core")
		e.hp -= 123.0
		var live_regions: Dictionary = game.data.regions.duplicate(true)
		var saved := game.snapshot(1000)
		suite.check(game.data.regions == live_regions,"Snapshot does not mutate live encounters when UI saves")
		suite.check(game.storage.valid_data(saved),"Active boss snapshot passes validation")
		game.save_path = "user://boss-"+kind+".save"
		suite.clean_test_save(game.save_path)
		suite.check(game.save(1000),"Active boss saved")
		var restored := VigilState.new()
		restored.save_path = game.save_path
		suite.check(restored.load_save(1010),"Active boss reloads")
		var live := restored.combat.enemies.filter(func(v): return v.get("boss",false) and v.source == source)
		suite.check(live.size() == 1 and live[0].hp == e.hp and live[0].pos.is_equal_approx(e.pos) and live[0].path.size() == e.path.size(),"Reload preserves boss health and road position")
		if live.size() == 1:
			for i in range(e.path.size()):
				suite.check(live[0].path[i].is_equal_approx(e.path[i]),"Saved road samples survive JSON float precision")
		var invalid := saved.duplicate(true)
		invalid.regions[source].boss.segment = 9999
		suite.check(not game.storage.valid_data(invalid),"Invalid boss segment is rejected")
		invalid = saved.duplicate(true)
		invalid.regions[source].boss.path[0][0] += 50.0
		suite.check(not game.storage.valid_data(invalid),"Off-road boss save is rejected")
		var tid := game.economy.build("heavy","0,0",0)
		e.wards = 0
		e.shield = 0.0
		game.combat.hit(e,1.0e6,tid,"doomstone")
		game.combat.hit(e,1.0e6,tid,"doomstone")
		suite.check(game.data.towers[tid].earnings == Bosses.DEFINITIONS[kind].payout and game.data.kills == 1,"Boss bounty is credited exactly once")
		suite.check(game.data.regions[source].history.is_empty(),"Boss bounty cannot become offline income")
		game.combat.recycle_dead_enemies()
		Bosses.awaken(game.combat,source)
		suite.check(game.combat.enemies.filter(func(v): return v.get("boss",false) and v.source == source).is_empty(),"Defeated cluster never respawns")
		suite.check(game.save(1010) and restored.load_save(1020),"Defeated boss saves and reloads")
		suite.check(restored.combat.enemies.filter(func(v): return v.get("boss",false) and v.source == source).is_empty(),"Reload cannot farm defeated boss")
		suite.clean_test_save(game.save_path)
	core_escape_checks(suite)
	var game := fixture("warden")
	var e: Dictionary = game.combat.enemies[0]
	var tid := game.economy.build("splash","0,0",0)
	game.combat.hit(e,100,tid,"cinderfield",true)
	suite.check(e.shield == 400 and e.hp == e.max_hp,"Rootburn doubles shield damage only")
	e.regen = 0.01
	game.combat.burning_ground.append({"tower_id":tid,"pos":e.pos,"radius":60.0,"until":10.0,"damage":10.0})
	Bosses.advance(game.combat,0.1)
	suite.check(e.shield == 400,"Warden shield stays damaged inside burning ground")
	game.combat.burning_ground.clear()
	Bosses.advance(game.combat,30.0)
	suite.check(e.shield == 400,"Warden shield stays damaged across former refill periods")
	game.combat.hit(e,200,tid,"cinderfield",true)
	e.regen = 0.0
	Bosses.advance(game.combat,30.0)
	suite.check(e.shield == 0 and e.hp == e.max_hp,"Broken Warden shield never refills with an expired legacy timer")
	game.combat.hit(e,100,tid)
	suite.check(e.hp == e.max_hp - 100,"Damage reaches health after the shield is broken")
	game = fixture("cindermaw")
	e = game.combat.enemies[0]
	tid = game.economy.build("rapid","0,0",0)
	e.hp = e.max_hp/2
	var before: float = e.hp
	suite.check(Bosses.speed(e,0) > Bosses.DEFINITIONS.cindermaw.speed,"Cracked furnace hastens")
	game.combat.branch_hit(shot(tid,"frostneedle"),e)
	suite.check(e.hp == before-150 and Bosses.speed(e,0) == Bosses.DEFINITIONS.cindermaw.speed and e.slow_until == 2,"Frost deals bonus damage and suppresses haste with ordinary slow")
	game = fixture("bell")
	e = game.combat.enemies[0]
	tid = game.economy.build("electric","0,0",0)
	for i in range(5):
		game.combat.branch_hit(shot(tid,"thunderseal",10),e)
	suite.check(e.hp == e.max_hp-95 and e.toll == 10,"Bell suffers boosted seal and two-second toll delay")
	for i in range(5):
		game.combat.branch_hit(shot(tid,"thunderseal",10),e)
	suite.check(e.toll == 10,"Multiple seals cannot delay a toll indefinitely")
	for i in range(3):
		e.toll = 0.01
		Bosses.advance(game.combat,0.1)
	suite.check(game.combat.enemies.size() == 7,"Bell summons at most six living escorts")
	game = fixture("prior")
	e = game.combat.enemies[0]
	tid = game.economy.build("heavy","0,0",0)
	game.combat.hit(e,100,tid)
	suite.check(e.hp == e.max_hp and e.wards == 2,"Wards absorb ordinary hits")
	game.combat.branch_hit(shot(tid,"doomstone"),e)
	suite.check(e.hp == e.max_hp-100 and e.wards == 2,"Doomstone bypasses crystal wards")
	for i in range(5):
		game.combat.branch_hit(shot(tid,"doomstone",10),e)
	e.pos = VigilWorld.pad_position("0,0",0)
	e.regen = 0.01
	Bosses.advance(game.combat,0.1)
	suite.check(e.wards == 2,"Full maintained curse prevents ward regrowth")
	game.combat.curses[tid].target = -1
	Bosses.advance(game.combat,0.1)
	suite.check(e.wards == 3,"Changing curse target restores ward regeneration")
	print("PASS GROUP: six biome bosses, patrol roads, counters, legacy persistence and one-time rewards")

static func legacy_encounters(suite: SceneTree) -> void:
	var game := preload("res://tests/unit/castle_checks.gd").fixture()
	var gate := Areas.gate(Vector2i.ZERO, 879)
	var old_kind := Bosses.legacy_kind_at(gate.id, 879, true)
	game.combat.enemies.clear()
	Bosses.create(game.combat, gate.id, old_kind)
	var saved := game.snapshot(1000)
	suite.check(game.storage.valid_data(saved), "Original randomly assigned castle boss remains a valid save")
	game.save_path = "user://biome-boss-legacy.save"
	suite.clean_test_save(game.save_path)
	suite.check(game.save(1000), "Legacy active castle boss saves")
	var restored := VigilState.new()
	restored.save_path = game.save_path
	suite.check(restored.load_save(1000), "Legacy active castle boss reloads")
	var bosses := restored.combat.enemies.filter(func(e): return e.get("boss", false) and e.source == gate.id)
	suite.check(bosses.size() == 1 and bosses[0].kind == old_kind, "Biome update preserves legacy identity without duplicate encounters")
	var invalid := saved.duplicate(true)
	invalid.castles[gate.id].boss.kind = "missing_boss"
	suite.check(not game.storage.valid_data(invalid), "Unknown saved bosses remain rejected")
	suite.clean_test_save(game.save_path)

static func core_escape_checks(suite: SceneTree) -> void:
	var loop_game := VigilState.new(879)
	var ring := ["1,0","1,1","0,1","-1,1","-1,0","-1,-1","0,-1","1,-1"]
	var parent := "0,0"
	for id in ring:
		loop_game.data.regions[id] = VigilWorld.make_region(id,parent,879)
		parent = id
	loop_game.refresh_paths()
	var walker := Bosses.create(loop_game.combat,"1,0","warden")
	var visited := {}
	for step in range(96):
		suite.check(walker.tile != "0,0" and walker.previous != "0,0","Ring patrol never traverses the core tile")
		visited[walker.tile] = true
		walker.pos = walker.path[-1]
		Bosses.next_leg(loop_game.combat,walker)
	suite.check(visited.size() == 8,"Boss explores every direction around a connected core ring")
	var game := fixture("warden")
	var e: Dictionary = game.combat.enemies[0]
	var leaf := ""
	for direction in VigilWorld.DIRS:
		var candidate := VigilWorld.key(direction)
		if game.data.regions.has(candidate):
			continue
		var neighbors := 0
		for d in VigilWorld.DIRS:
			if game.data.regions.has(VigilWorld.key(direction+d)):
				neighbors += 1
		if neighbors == 1:
			leaf = candidate
			break
	game.data.regions[leaf] = VigilWorld.make_region(leaf,"0,0",879)
	game.refresh_paths()
	e.tile = leaf
	e.previous = ""
	e.pos = VigilWorld.center(leaf)
	Bosses.next_leg(game.combat,e)
	suite.check(e.tile == "0,0","Core-only exit becomes a final escape leg")
	e.segment = 2
	e.pos = e.path[1]
	var position: Vector2 = e.pos
	var extra := VigilWorld.key(VigilWorld.coord(leaf)*2)
	game.data.regions[extra] = VigilWorld.make_region(extra,leaf,879)
	game.refresh_paths()
	# A legacy inbound save remains valid; restore redirects it without warping.
	game.save_path = "user://boss-redirect.save"
	suite.clean_test_save(game.save_path)
	suite.check(game.save(1000),"Inbound legacy boss can be saved")
	var restored := VigilState.new()
	restored.save_path = game.save_path
	suite.check(restored.load_save(1001),"Inbound legacy boss reloads")
	var loaded: Dictionary = restored.combat.enemies.filter(func(v): return v.source == e.source and v.get("boss",false))[0]
	suite.check(loaded.tile == leaf and loaded.pos.is_equal_approx(position),"Reload reverses forbidden core route on the same road")
	Bosses.avoid_core(game.combat,e)
	suite.check(e.tile == leaf and e.pos == position,"New road redirects inbound boss without teleporting")
	suite.check(game.storage.valid_data(game.snapshot(1001)),"Reversed road remains valid for saves")
	e.pos = e.path[-1]
	Bosses.next_leg(game.combat,e)
	suite.check(e.tile == extra,"Boss chooses non-core route after turning back")
	e.pos = e.path[-1]
	Bosses.next_leg(game.combat,e)
	e.pos = e.path[-1]
	Bosses.next_leg(game.combat,e)
	suite.check(e.tile == extra,"Backtracking wins over escaping into core")
	# With only the core available, arrival ends this encounter once, without gold.
	game.data.regions.erase(extra)
	game.refresh_paths()
	e.tile = leaf
	e.previous = ""
	e.pos = VigilWorld.center(leaf)
	Bosses.next_leg(game.combat,e)
	e.segment = e.path.size()-1
	e.pos = e.path[-1]
	for region in game.data.regions.values():
		region.timer = 9.0
	game.combat.tick(0.05)
	suite.check(game.data.escapes == 1 and game.data.kills == 0 and game.data.lifetime_earnings == 0,"Boss core arrival escapes once without a bounty")
	suite.check(game.data.regions[e.source].boss.status == "escaped","Escaped encounter is marked complete")
	suite.check(game.save(1002) and restored.load_save(1003),"Escaped boss state persists")
	suite.check(restored.combat.enemies.filter(func(v): return v.source == e.source and v.get("boss",false)).is_empty(),"Escaped cluster cannot respawn after reload")
	suite.clean_test_save(game.save_path)
