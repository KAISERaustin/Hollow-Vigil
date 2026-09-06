extends RefCounted

const Areas = preload("res://scripts/world/hidden_areas.gd")
const TYPES := ["warden", "cindermaw", "bell", "prior"]
const DEFINITIONS := {
	"warden": {"name": "Briarbound Warden", "hp": 3200.0, "speed": 27.0, "payout": 450.0, "color": "95aa83", "weakness": "Cinderfield: burns roots; blocks regrowth"},
	"cindermaw": {"name": "Cindermaw", "hp": 3600.0, "speed": 25.0, "payout": 500.0, "color": "db8d73", "weakness": "Frostneedle: +50% damage; quenches haste"},
	"bell": {"name": "The Drowned Bell", "hp": 2800.0, "speed": 32.0, "payout": 450.0, "color": "93c9bc", "weakness": "Thunderseal: stronger seals; delays tolls"},
	"prior": {"name": "The Eclipse Prior", "hp": 3000.0, "speed": 30.0, "payout": 500.0, "color": "b49dcc", "weakness": "Doomstone: bypasses wards; curses regrowth"}
}

# The first generated cell is already fixed independently of purchase order.
static func kind_at(id: String, seed_value: int) -> String:
	var sector := Areas.sector_for(VigilWorld.coord(id))
	if VigilWorld.key(Areas.cluster(sector, seed_value)[0]) != id:
		return ""
	return TYPES[absi(("cluster-boss:" + str(sector) + ":" + str(seed_value)).hash()) % TYPES.size()]

static func awaken(combat: VigilCombat, id: String) -> void:
	var region: Dictionary = combat.data.regions[id]
	var kind := kind_at(id, int(combat.data.seed))
	if kind == "" or region.has("boss"):
		return
	region.boss = {"status": "active", "kind": kind}
	create(combat, id, kind)

static func create(combat: VigilCombat, id: String, kind: String) -> Dictionary:
	combat.enemy_serial += 1
	var e := {"id": combat.enemy_serial, "source": id, "kind": kind, "boss": true,
		"hp": DEFINITIONS[kind].hp, "max_hp": DEFINITIONS[kind].hp, "dead": false,
		"pos": VigilWorld.center(id), "segment": 1, "path": [], "tile": id,
		"previous": "", "steps": 0, "shield": 600.0 if kind == "warden" else 0.0,
		"wards": 3 if kind == "prior" else 0, "regen": 10.0, "toll": 8.0, "toll_delayed": false}
	next_leg(combat, e)
	combat.enemies.append(e)
	return e

static func next_leg(combat: VigilCombat, e: Dictionary) -> void:
	var choices: Array[String] = []
	for direction in VigilWorld.DIRS:
		var neighbor := VigilWorld.key(VigilWorld.coord(e.tile) + direction)
		if combat.data.regions.has(neighbor):
			choices.append(neighbor)
	# Avoid immediate reversal unless at a dead end. Every fourth crossing takes
	# a detour; other crossings prefer the core's neighborhood. Never teleport.
	if choices.size() > 1:
		choices.erase(e.previous)
	var next: String = choices[int(e.steps) % choices.size()]
	if int(e.steps) % 4 != 0:
		for choice in choices:
			if combat.paths[choice].size() < combat.paths[next].size():
				next = choice
	var side := VigilWorld.DIRS.find(VigilWorld.coord(next) - VigilWorld.coord(e.tile))
	var path := VigilWorld.spoke(combat.data.regions[e.tile], side)
	path.reverse()
	path.append_array(VigilWorld.spoke(combat.data.regions[next], (side + 2) % 4).slice(1))
	e.path = path
	e.segment = 1
	e.previous = e.tile
	e.tile = next
	e.steps += 1

static func speed(e: Dictionary, now: float) -> float:
	var value: float = DEFINITIONS[e.kind].speed
	if e.kind == "cindermaw" and e.hp <= e.max_hp * 0.5 and e.get("slow_until", 0.0) <= now:
		value *= 1.7
	return value

static func damage(e: Dictionary, amount: float, branch: String, fire: bool) -> float:
	if e.kind == "cindermaw":
		if branch == "frostneedle":
			amount *= 1.5
		if e.hp > e.max_hp * 0.5:
			amount *= 0.7
	if e.kind == "prior" and e.wards > 0 and branch != "doomstone":
		e.wards -= 1
		return 0.0
	if e.kind == "warden" and e.shield > 0.0:
		var multiplier := 2.0 if fire else 1.0
		var absorbed := minf(e.shield, amount * multiplier)
		e.shield -= absorbed
		amount -= absorbed / multiplier
	return amount

static func advance(combat: VigilCombat, delta: float) -> void:
	# Spawn escorts after iterating the original list, never recursively in-loop.
	var bells: Array[Dictionary] = []
	for e in combat.enemies:
		if e.dead or not e.get("boss", false):
			continue
		var blocked := false
		if e.kind == "warden":
			for patch in combat.burning_ground:
				if patch.until > combat.simulation_time and combat.data.towers.has(patch.tower_id) and e.pos.distance_to(patch.pos) <= patch.radius:
					blocked = true
		if e.kind == "prior":
			for tid in combat.curses:
				var curse: Dictionary = combat.curses[tid]
				if curse.target == e.id and curse.stacks == 5 and combat.data.towers.has(tid):
					var t: Dictionary = combat.data.towers[tid]
					if t.get("rebuild_remaining", 0.0) <= 0.0 and VigilWorld.pad_position(t.region, t.pad).distance_to(e.pos) <= Balance.tower_stats(t, combat.tuning).range:
						blocked = true
		if not blocked:
			e.regen = maxf(0.0, e.regen - delta)
			if e.regen <= 0.0:
				e.shield = 600.0 if e.kind == "warden" else 0.0
				e.wards = 3 if e.kind == "prior" else 0
				e.regen = 10.0
		if e.kind == "bell":
			e.toll -= delta
			if e.toll <= 0.0:
				e.toll = 8.0
				e.toll_delayed = false
				bells.append(e)
	for bell in bells:
		var count := 0
		for e in combat.enemies:
			if not e.dead and e.get("summoner", -1) == bell.id:
				count += 1
		for index in range(mini(3, 6 - count)):
			var escort := combat.spawn(bell.source, "basic")
			escort.summoner = bell.id
			escort.rift_style = "forest"
			escort.hp = Balance.ENEMIES.basic.hp
			escort.max_hp = escort.hp
			escort.pos = bell.pos
			escort.path = [bell.pos]
			escort.path.append_array(bell.path.slice(bell.segment))
			escort.path.append_array(combat.paths[bell.tile].slice(1))
			escort.segment = 1

static func capture(combat: VigilCombat, regions: Dictionary) -> void:
	for e in combat.enemies:
		if not e.get("boss", false) or e.dead:
			continue
		var saved := {"status": "active", "kind": e.kind, "pos": [e.pos.x, e.pos.y], "path": []}
		for point in e.path:
			saved.path.append([point.x, point.y])
		for field in ["hp", "segment", "tile", "previous", "steps", "shield", "wards", "regen", "toll", "toll_delayed"]:
			saved[field] = e[field]
		regions[e.source].boss = saved

static func restore(combat: VigilCombat) -> void:
	for id in combat.data.regions:
		var saved: Dictionary = combat.data.regions[id].get("boss", {})
		# Existing worlds gain their previously uncovered encounter once. Once
		# captured, both active and defeated records prevent a second awakening.
		if saved.is_empty():
			awaken(combat, id)
			continue
		if saved.get("status", "") != "active":
			continue
		var e := create(combat, id, saved.kind)
		for field in ["hp", "segment", "tile", "previous", "steps", "shield", "wards", "regen", "toll", "toll_delayed"]:
			e[field] = saved[field]
		e.segment = int(e.segment)
		e.pos = Vector2(saved.pos[0], saved.pos[1])
		e.path = []
		for point in saved.path:
			e.path.append(Vector2(point[0], point[1]))
