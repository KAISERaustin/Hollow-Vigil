extends RefCounted

const TYPES := ["warden", "cindermaw", "bell", "prior", "ruined_king", "mourning_matriarch"]
const DEFINITIONS = Balance.BOSSES

# Saved encounters retain their identities; new encounters use the tile's biome.
static func record(combat: VigilCombat, id: String) -> Dictionary:
	return combat.data.castles[id] if combat.data.castles.has(id) else combat.data.regions[id]

static func create(combat: VigilCombat, id: String, kind: String, authored_path: Array[Vector2]) -> Dictionary:
	combat.enemy_serial += 1
	var e := Balance.Content.boss(kind).create_encounter(combat.enemy_serial, id, authored_path[0], combat.tuning)
	combat.EnemyCapabilities.initialize(e, combat.tuning)
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

static func advance(combat: VigilCombat, _delta: float) -> void:
	for enemy in combat.enemies:
		if enemy.dead or not enemy.get("boss", false): continue
		if enemy.get("stun_until", 0.0) <= combat.simulation_time and combat.simulation_time >= enemy.get("next_footfall", 0.0):
			enemy.next_footfall = combat.simulation_time + 1.5
			combat.sound_requested.emit(Balance.Content.boss(enemy.kind).sound_cue("step"), enemy.pos)
