extends RefCounted

const TYPES := ["warden", "cindermaw", "bell", "prior", "ruined_king", "mourning_matriarch"]
const DEFINITIONS = Balance.BOSSES

# Saved encounters retain their identities; new encounters use the tile's biome.
static func record(combat: VigilCombat, id: String) -> Dictionary:
	return combat.data.castles[id] if combat.data.castles.has(id) else combat.data.regions[id]

static func create(combat: VigilCombat, id: String, kind: String, authored_path: Array[Vector2]) -> Dictionary:
	combat.enemy_serial += 1
	var e := Balance.Content.boss(kind).create_encounter(combat.enemy_serial, id, authored_path[0], combat.tuning)
	e.path = authored_path
	e.pos = authored_path[0]
	e.tile = "0,0"
	e.authored_route = true
	combat.enemies.append(e)
	combat.set_enemy_route(e, e.path)
	combat.sound_requested.emit(Balance.Content.boss(kind).sound_cue("awaken"), e.pos)
	return e

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
		if e.kind == "prior":
			for tid in combat.curses:
				var curse: Dictionary = combat.curses[tid]
				if curse.target == e.id and curse.stacks >= stats.curse_threshold and combat.data.towers.has(tid):
					var t: Dictionary = combat.data.towers[tid]
					if t.get("rebuild_remaining", 0.0) <= 0.0 and VigilWorld.pad_position(t.region, t.pad).distance_to(e.pos) <= Balance.tower_stats(t, combat.tuning, combat.data.relics).range:
						blocked = true
		if e.kind == "prior":
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
			var remaining: Array[Vector2] = [bell.pos]
			remaining.append_array(bell.path.slice(bell.segment))
			var escort := combat.spawn_on_path(kind, remaining)
			if escort.is_empty():
				continue
			escort.summoner = bell.id
			escort.rift_style = "forest"
			escort.hp = Balance.tuned_value("enemies", kind, "hp", combat.tuning)
			escort.max_hp = escort.hp
			escort.pos = bell.pos
			escort.path = [bell.pos]
			escort.path.append_array(bell.path.slice(bell.segment))
			escort.segment = 1
			combat.set_enemy_route(escort, escort.path)
