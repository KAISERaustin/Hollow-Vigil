extends RefCounted

# Each encounter's source coordinate is the permanent identity of its drop.
const DEFINITIONS = preload("res://scripts/content/catalogs/gear.gd").PRESENTATION
const BOSS_DROPS = preload("res://scripts/content/catalogs/gear.gd").BOSS_DROPS

static func description(relic_kind: String, tuning: Dictionary = {}) -> String:
	if not DEFINITIONS.has(relic_kind):
		return ""
	var gear := Balance.definition("gear", relic_kind, tuning)
	for stat in gear:
		if gear[stat] is float or gear[stat] is int:
			gear[stat] = String.num(gear[stat], 2).trim_suffix(".0")
	return DEFINITIONS[relic_kind].description.format(gear)

static func kind(data: Dictionary, tower: Dictionary) -> String:
	return data.get("relics", {}).get(tower.get("relic", ""), "")

static func owner(data: Dictionary, relic_id: String) -> String:
	if relic_id == "":
		return ""
	for tower in data.towers.values():
		if tower.get("relic", "") == relic_id:
			return tower.id
	return ""

static func migrate(data: Dictionary) -> void:
	if not data.has("relics"):
		data.relics = {}
	# Older progress receives each recorded victory once, without paying gold again.
	for records in [data.regions, data.get("castles", {})]:
		for source in records:
			var boss: Dictionary = records[source].get("boss", {})
			if boss.get("status", "") == "defeated":
				award_set(data, source, boss.get("kind", ""))

static func drop_id(source: String, gear_kind: String, boss_kind: String) -> String:
	return source if gear_kind == boss_kind else source + "#" + gear_kind

static func award_set(data: Dictionary, source: String, boss_kind: String) -> Array[String]:
	var awarded: Array[String] = []
	for gear_kind in BOSS_DROPS.get(boss_kind, []):
		if award(data, drop_id(source, gear_kind, boss_kind), gear_kind):
			awarded.append(gear_kind)
	return awarded

static func award(data: Dictionary, source: String, boss_kind: String) -> bool:
	if not data.has("relics"):
		data.relics = {}
	if data.relics.has(source) or not DEFINITIONS.has(boss_kind):
		return false
	data.relics[source] = boss_kind
	return true

static func prepare(combat: VigilCombat, tower: Dictionary, target: Dictionary, stats: Dictionary) -> Dictionary:
	var relic_kind := kind(combat.data, tower)
	if relic_kind == "":
		return stats
	var node := Balance.Content.gear(relic_kind)
	var progress: Dictionary = combat.relic_progress.get(tower.id, node.make_record())
	var result := node.prepare(progress, target.id, combat.simulation_time, stats, combat.tuning)
	result.gear_epoch = combat.relic_epochs.get(tower.id, 0)
	result.gear_color = DEFINITIONS[relic_kind].color
	combat.relic_progress[tower.id] = progress
	return result

static func root_target(combat: VigilCombat, shot: Dictionary, enemy: Dictionary) -> void:
	if not shot.get("relic_root", false):
		return
	apply_root(combat, shot, enemy, Balance.definition("gear", "warden", combat.tuning))

static func apply_root(combat: VigilCombat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	if enemy.id != shot.get("target_id", -1) or enemy.get("root_immune_until", 0.0) > combat.simulation_time:
		return
	var until: float = combat.simulation_time + (config.boss_root_duration if enemy.get("boss", false) else config.root_duration)
	enemy.root_until = maxf(enemy.get("root_until", 0.0), until)
	enemy.root_immune_until = combat.simulation_time + config.root_immunity
	if shot.has("tower_id"):
		add_status(enemy, shot.tower_id, "attribute/root", {"type": "root", "until": until})

static func apply_balance(combat: VigilCombat, previous: Dictionary, tuning: Dictionary) -> void:
	for id in combat.relic_progress:
		if not combat.data.towers.has(id):
			continue
		var relic_kind := kind(combat.data, combat.data.towers[id])
		var node := Balance.Content.gear(relic_kind)
		if node != null:
			node.retune(combat.relic_progress[id], combat.simulation_time, previous, tuning)

static func impact(combat: VigilCombat, shot: Dictionary, enemy: Dictionary) -> void:
	if not shot.has("gear_effects"):
		root_target(combat, shot, enemy)
		return
	if shot.get("gear_epoch", -1) != combat.relic_epochs.get(shot.tower_id, 0):
		return
	for entry in shot.gear_effects:
		entry.attribute.impact(combat, shot, enemy, entry.config)

static func add_status(enemy: Dictionary, tower_id: String, attribute_id: String, status: Dictionary) -> void:
	var statuses: Dictionary = enemy.get("gear_status", {})
	status.owner = tower_id
	statuses[tower_id + ":" + attribute_id] = status
	enemy.gear_status = statuses

static func strength(enemy: Dictionary, type: String, now: float) -> float:
	var value := 0.0
	for status in enemy.get("gear_status", {}).values():
		if status.type == type and status.until > now:
			value = maxf(value, status.get("strength", 100.0))
	return value

static func hindered(enemy: Dictionary, now: float) -> bool:
	return enemy.get("root_until", 0.0) > now or enemy.get("stun_until", 0.0) > now or (enemy.get("slow_until", 0.0) > now and enemy.get("slow_percent", 0.0) > 0.0) or strength(enemy, "slow", now) > 0.0 or strength(enemy, "stun", now) > 0.0

static func push_resistance(combat: VigilCombat, enemy: Dictionary) -> float:
	return Balance.tuned_value("bosses" if enemy.get("boss", false) else "enemies", enemy.kind, "push_resistance", combat.tuning)

static func advance(combat: VigilCombat, delta: float) -> void:
	for enemy in combat.enemies:
		var statuses: Dictionary = enemy.get("gear_status", {})
		for key in statuses.keys():
			var status: Dictionary = statuses[key]
			if not enemy.dead and status.type == "dot" and combat.data.towers.has(status.owner):
				var elapsed := clampf(status.until - (combat.simulation_time - delta), 0.0, delta)
				combat.hit(enemy, status.damage * elapsed, status.owner, "", status.fire)
			if status.until <= combat.simulation_time or enemy.dead or not combat.data.towers.has(status.owner):
				statuses.erase(key)

static func clear(combat: VigilCombat, tower_id: String) -> void:
	combat.relic_progress.erase(tower_id)
	combat.relic_epochs[tower_id] = int(combat.relic_epochs.get(tower_id, 0)) + 1
	for enemy in combat.enemies:
		var statuses: Dictionary = enemy.get("gear_status", {})
		var had_root := false
		for key in statuses.keys():
			if statuses[key].owner == tower_id:
				had_root = had_root or statuses[key].type == "root"
				statuses.erase(key)
		if had_root:
			enemy.root_until = 0.0
			for status in statuses.values():
				if status.type == "root":
					enemy.root_until = maxf(enemy.root_until, status.until)
