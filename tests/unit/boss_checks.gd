extends RefCounted

const Bosses = preload("res://scripts/model/bosses.gd")
const Areas = preload("res://scripts/world/hidden_areas.gd")

static func fixture(kind: String) -> VigilState:
	var game := VigilState.new(879)
	game.data.balance = 1.0e30
	game.data.first_property_required = false
	var target := Vector2i.ZERO
	for y in range(-3,4):
		for x in range(-3,4):
			var cell := Areas.cluster(Vector2i(x,y),879)[0]
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
	for y in range(-3,4):
		for x in range(-3,4):
			var cells := Areas.cluster(Vector2i(x,y),879)
			var count := 0
			for cell in cells:
				var kind := Bosses.kind_at(VigilWorld.key(cell),879)
				if kind != "":
					count += 1
					kinds[kind] = true
			suite.check(count == 1,"Exactly one fixed boss tile per cluster")
	suite.check(kinds.size() == 4,"All four boss types occur across clusters")
	for kind in Bosses.TYPES:
		var game := fixture(kind)
		var e: Dictionary = game.combat.enemies[0]
		var source: String = e.source
		Bosses.awaken(game.combat,source)
		suite.check(game.combat.enemies.size() == 1,"Repeated unlock cannot duplicate a boss")
		# Exercise the real purchase trigger with this already-connected frontier.
		game.data.regions.erase(source)
		game.combat.enemies.clear()
		game.refresh_paths()
		suite.check(game.expand(source),"Boss tile can be purchased normally")
		suite.check(game.combat.enemies.size() == 1,"Purchasing boss tile summons exactly one boss")
		e = game.combat.enemies[0]
		for r in game.data.regions.values():
			r.timer = 9.0
		var original_leg: Array = e.path.duplicate()
		var frontier := VigilWorld.frontier(game.data.regions)
		game.expand(frontier.keys()[0])
		suite.check(e.path == original_leg,"Expansion preserves an existing patrol leg")
		# Exercise the actual tick transition at the end of a leg, including core.
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
		suite.check(seen.has("0,0") and seen.size() > 1 and not e.dead,"Boss visits and leaves core alive")
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
	var game := fixture("warden")
	var e: Dictionary = game.combat.enemies[0]
	var tid := game.economy.build("splash","0,0",0)
	game.combat.hit(e,100,tid,"cinderfield",true)
	suite.check(e.shield == 400 and e.hp == e.max_hp,"Rootburn doubles shield damage only")
	e.regen = 0.01
	game.combat.burning_ground.append({"tower_id":tid,"pos":e.pos,"radius":60.0,"until":10.0,"damage":10.0})
	Bosses.advance(game.combat,0.1)
	suite.check(e.shield == 400,"Burning ground blocks shield regrowth")
	game.combat.burning_ground.clear()
	Bosses.advance(game.combat,0.1)
	suite.check(e.shield == 600,"Shield regrows outside fire")
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
	print("PASS GROUP: boss clusters, patrol roads, counters, persistence and one-time rewards")
