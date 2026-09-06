extends RefCounted

const Areas = preload("res://scripts/world/hidden_areas.gd")
const Clusters = preload("res://scripts/world/biome_clusters.gd")
const TYPES := ["warden", "cindermaw", "bell", "prior", "ruined_king", "mourning_matriarch"]
const DEFINITIONS = Balance.BOSSES

# Saved encounters retain their identities; new encounters use the tile's biome.
static func kind_at(id: String, seed_value: int, style: String = "") -> String:
	if id == "0,0":
		return ""
	var biome := Balance.Content.region(style if style != "" else VigilWorld.region_style(id, seed_value))
	return biome.boss_kind() if biome != null else ""

static func legacy_kind_at(id: String, seed_value: int, castle: bool = false) -> String:
	var sector := Areas.sector_for(VigilWorld.coord(id))
	if not castle and VigilWorld.key(Areas.cluster(sector, seed_value)[0]) != id:
		return ""
	return TYPES[absi(("cluster-boss:" + str(sector) + ":" + str(seed_value)).hash()) % 4]

static func awaken(combat: VigilCombat, id: String) -> void:
	var cluster := Clusters.at(id, int(combat.data.seed))
	if cluster.boss_tile != id or has_encounter(combat.data, cluster):
		return
	var region: Dictionary = combat.data.regions[id]
	var kind := kind_at(id, int(combat.data.seed), region.style)
	if kind == "" or region.has("boss"):
		return
	region.boss = {"status": "active", "kind": kind}
	create(combat, id, kind)
	capture(combat, combat.data.regions, combat.data.castles)

static func has_encounter(data: Dictionary, cluster: Dictionary) -> bool:
	for cell in cluster.cells:
		var id := VigilWorld.key(cell)
		if data.regions.get(id, {}).has("boss") or data.get("castles", {}).get(id, {}).has("boss"):
			return true
	return false

static func normalize_encounters(data: Dictionary) -> void:
	# Collapse the previous per-tile release on load. Completed records and
	# earned relics stay intact; extra active bosses disappear without rewards.
	var records: Dictionary = data.regions.duplicate()
	records.merge(data.get("castles", {}), true)
	var groups := {}
	for id in records:
		if not records[id].has("boss"):
			continue
		var cluster := Clusters.at(id, int(data.seed))
		if not groups.has(cluster.id):
			groups[cluster.id] = []
		groups[cluster.id].append(id)
	for ids in groups.values():
		ids.sort()
		var chosen: String = ids[0]
		var site: String = Clusters.at(chosen, int(data.seed)).boss_tile
		for id in ids:
			var completed: bool = records[id].boss.status != "active"
			if completed or (records[chosen].boss.status == "active" and id == site):
				chosen = id
		for id in ids:
			if id != chosen and records[id].boss.status == "active":
				records[id].erase("boss")

static func record(combat: VigilCombat, id: String) -> Dictionary:
	return combat.data.castles[id] if combat.data.castles.has(id) else combat.data.regions[id]

static func castle_kind(_sector: Vector2i, _seed_value: int) -> String:
	return Balance.Content.region("castle_ruin").boss_kind()

static func discover_castles(combat: VigilCombat) -> void:
	var sectors := {}
	for id in combat.data.regions:
		for direction in VigilWorld.DIRS:
			sectors[Areas.sector_for(VigilWorld.coord(id) + direction)] = true
	for sector in sectors:
		if Areas.preserved(sector, int(combat.data.seed), combat.data.regions):
			continue
		var g := Areas.gate(sector, int(combat.data.seed))
		if combat.paths.has(g.neighbor) and not has_encounter(combat.data, Clusters.at(g.id, int(combat.data.seed))):
			var kind := castle_kind(sector, int(combat.data.seed))
			combat.data.castles[g.id] = {"boss": {"status": "active", "kind": kind}}
			create(combat, g.id, kind)
			capture(combat, combat.data.regions, combat.data.castles)

static func create(combat: VigilCombat, id: String, kind: String, authored_path: Array[Vector2] = []) -> Dictionary:
	combat.enemy_serial += 1
	var e := Balance.Content.boss(kind).create_encounter(combat.enemy_serial, id, VigilWorld.center(id), combat.tuning)
	if not authored_path.is_empty():
		e.path = authored_path
		e.pos = authored_path[0]
		e.tile = "0,0"
		e.authored_route = true
	elif not combat.data.regions.has(id):
		var g := Areas.gate(Areas.sector_for(VigilWorld.coord(id)), int(combat.data.seed))
		e.path = Areas.emergence(g, combat.data.regions)
		e.pos = e.path[0]
		e.previous = id
		e.tile = g.neighbor
		e.steps = 1
	else:
		next_leg(combat, e)
	combat.enemies.append(e)
	combat.sound_requested.emit(Balance.Content.boss(kind).sound_cue("awaken"), e.pos)
	return e

static func next_leg(combat: VigilCombat, e: Dictionary) -> void:
	var choices: Array[String] = []
	for direction in VigilWorld.DIRS:
		var neighbor := VigilWorld.key(VigilWorld.coord(e.tile) + direction)
		if combat.data.regions.has(neighbor):
			choices.append(neighbor)
	# Exclude the core BEFORE avoiding reversal: even turning back is better
	# than entering the core. Only a tile with no other owned exit may escape.
	if choices.size() > 1:
		choices.erase("0,0")
	if choices.size() > 1:
		choices.erase(e.previous)
	var next: String = choices[int(e.steps) % choices.size()]
	var side := VigilWorld.DIRS.find(VigilWorld.coord(next) - VigilWorld.coord(e.tile))
	var path := VigilWorld.spoke(combat.data.regions[e.tile], side)
	path.reverse()
	path.append_array(VigilWorld.spoke(combat.data.regions[next], (side + 2) % 4).slice(1))
	e.path = path
	e.segment = 1
	e.previous = e.tile
	e.tile = next
	e.steps += 1

static func avoid_core(combat: VigilCombat, e: Dictionary) -> void:
	if e.get("authored_route", false):
		return
	# An older save or a new purchase may expose a non-core alternative while
	# the boss is already inbound. Retrace its current road without teleporting.
	if e.tile != "0,0":
		return
	for direction in VigilWorld.DIRS:
		var neighbor := VigilWorld.key(VigilWorld.coord(e.previous) + direction)
		if neighbor != "0,0" and combat.data.regions.has(neighbor):
			e.path = e.path.duplicate()
			e.path.reverse()
			e.segment = e.path.size() - int(e.segment)
			e.tile = e.previous
			e.previous = "0,0"
			return

# Keep damage and timer progress when a live encounter is retuned or reset.
static func apply_balance(e: Dictionary, previous: Dictionary, tuning: Dictionary) -> void:
	var before := Balance.definition("bosses", e.kind, previous)
	var after := Balance.definition("bosses", e.kind, tuning)
	for field in ["shield", "wards", "regen", "toll"]:
		var stat: String = {"regen": "regen_period", "toll": "toll_period"}.get(field, field)
		if not after.has(stat):
			continue
		var old_limit: float = before[stat]
		var new_limit: float = after[stat]
		if field == "toll" and e.toll_delayed:
			old_limit += before.toll_delay
			new_limit += after.toll_delay
		if old_limit == new_limit:
			continue
		var remaining := clampf(e[field] / old_limit, 0.0, 1.0) if old_limit > 0.0 else 1.0
		e[field] = new_limit * remaining
		if field == "wards":
			e[field] = ceili(e[field])

static func speed(e: Dictionary, now: float, tuning: Dictionary = {}) -> float:
	return Balance.Content.boss(e.kind).movement_speed(e, now, tuning)

static func damage(e: Dictionary, amount: float, branch: String, fire: bool, tuning: Dictionary = {}, pierce: bool = false) -> float:
	return Balance.Content.boss(e.kind).absorb_damage(e, amount, branch, fire, tuning, pierce)

static func advance(combat: VigilCombat, delta: float) -> void:
	# Spawn escorts after iterating the original list, never recursively in-loop.
	var bells: Array[Dictionary] = []
	for e in combat.enemies:
		if e.dead or not e.get("boss", false):
			continue
		avoid_core(combat, e)
		# Footfalls use transient simulation timestamps, and stop when stunned.
		if e.get("stun_until", 0.0) <= combat.simulation_time and combat.simulation_time >= e.get("next_footfall", 0.0):
			e.next_footfall = combat.simulation_time + 1.5
			combat.sound_requested.emit(Balance.Content.boss(e.kind).sound_cue("step"), e.pos)
		var stats := Balance.definition("bosses", e.kind, combat.tuning)
		if e.kind == "cindermaw":
			var raging: bool = e.hp <= e.max_hp * stats.rage_threshold / 100.0
			if raging and not e.get("audio_raging", false):
				combat.sound_requested.emit("boss_cindermaw_ability", e.pos)
			e.audio_raging = raging
		var blocked := false
		if e.kind == "warden":
			for patch in combat.burning_ground:
				if patch.until > combat.simulation_time and combat.data.towers.has(patch.tower_id) and e.pos.distance_to(patch.pos) <= patch.radius:
					blocked = true
		if e.kind == "prior":
			for tid in combat.curses:
				var curse: Dictionary = combat.curses[tid]
				if curse.target == e.id and curse.stacks >= stats.curse_threshold and combat.data.towers.has(tid):
					var t: Dictionary = combat.data.towers[tid]
					if t.get("rebuild_remaining", 0.0) <= 0.0 and VigilWorld.pad_position(t.region, t.pad).distance_to(e.pos) <= Balance.tower_stats(t, combat.tuning).range:
						blocked = true
		if e.kind in ["warden", "prior"]:
			var rate: float = 1.0 - stats.regrowth_suppression / 100.0 if blocked else 1.0
			e.regen = maxf(0.0, e.regen - delta * rate)
			if e.regen <= 0.0 and rate > 0.0:
				e.shield = stats.get("shield", 0.0)
				e.wards = int(stats.get("wards", 0))
				e.regen = stats.regen_period
				combat.sound_requested.emit("boss_" + e.kind + "_ability", e.pos)
		if e.kind == "bell":
			e.toll -= delta
			if e.toll <= 0.0:
				e.toll = stats.toll_period
				e.toll_delayed = false
				bells.append(e)
				combat.sound_requested.emit("boss_bell_ability", e.pos)
	for bell in bells:
		var count := 0
		for e in combat.enemies:
			if not e.dead and e.get("summoner", -1) == bell.id:
				count += 1
		var stats := Balance.definition("bosses", "bell", combat.tuning)
		for index in range(maxi(0, mini(int(stats.escort_count), int(stats.escort_limit) - count))):
			var kind: String = Balance.ESCORT_KINDS[int(stats.escort_kind)]
			var authored: bool = bell.get("authored_route", false)
			var remaining: Array[Vector2] = [bell.pos]
			remaining.append_array(bell.path.slice(bell.segment))
			var escort := combat.spawn_on_path(kind, remaining) if authored else combat.spawn(bell.tile, kind, true)
			if escort.is_empty():
				continue
			escort.summoner = bell.id
			escort.rift_style = "forest"
			escort.hp = Balance.tuned_value("enemies", kind, "hp", combat.tuning)
			escort.max_hp = escort.hp
			escort.pos = bell.pos
			escort.path = [bell.pos]
			escort.path.append_array(bell.path.slice(bell.segment))
			if not authored:
				escort.path.append_array(combat.paths[bell.tile].slice(1))
			escort.segment = 1

static func capture(combat: VigilCombat, regions: Dictionary, castles: Dictionary = {}) -> void:
	for e in combat.enemies:
		if not e.get("boss", false) or e.dead:
			continue
		var saved := {"status": "active", "kind": e.kind, "pos": [e.pos.x, e.pos.y], "path": []}
		for point in e.path:
			saved.path.append([point.x, point.y])
		for field in ["hp", "segment", "tile", "previous", "steps", "shield", "wards", "regen", "toll", "toll_delayed"]:
			saved[field] = e[field]
		(castles[e.source] if castles.has(e.source) else regions[e.source]).boss = saved

static func restore(combat: VigilCombat) -> void:
	normalize_encounters(combat.data)
	var records: Dictionary = combat.data.regions.duplicate()
	records.merge(combat.data.get("castles", {}), true)
	for id in records:
		var saved: Dictionary = records[id].get("boss", {})
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
		avoid_core(combat, e)
	discover_castles(combat)
