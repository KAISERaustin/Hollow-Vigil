extends RefCounted

const Stats = preload("res://scripts/content/catalogs/stats.gd")
const ORDER := ["rage", "wards", "shield", "regrowth", "summon"]

static func category(enemy: Dictionary) -> String:
	return "bosses" if enemy.get("boss", false) else "enemies"

static func has(enemy: Dictionary, ability: String, tuning: Dictionary) -> bool:
	return Stats.ability_enabled(category(enemy), enemy.kind, ability, tuning)

static func resistance(enemy: Dictionary, field: String, tuning: Dictionary) -> float:
	var node = Balance.Content.catalog().get_node("resistance/" + field)
	return node.multiplier(Balance.definition(category(enemy), enemy.kind, tuning))

static func initialize(enemy: Dictionary, tuning: Dictionary) -> void:
	var stats := Balance.definition(category(enemy), enemy.kind, tuning)
	enemy.shield = 0.0
	enemy.wards = 0
	for ability in ORDER:
		if has(enemy, ability, tuning): Balance.Content.catalog().get_node("enemy_ability/" + ability).initialize(enemy, stats)

static func damage(enemy: Dictionary, amount: float, tags: Array, fire: bool, tuning: Dictionary, bypass: bool) -> float:
	var stats := Balance.definition(category(enemy), enemy.kind, tuning)
	for ability in ORDER:
		if has(enemy, ability, tuning): amount = Balance.Content.catalog().get_node("enemy_ability/" + ability).absorb(enemy, amount, tags, fire, bypass, stats)
	return amount

static func speed(enemy: Dictionary, now: float, tuning: Dictionary, slow: float) -> float:
	if not has(enemy, "rage", tuning): return 1.0
	return Balance.Content.catalog().get_node("enemy_ability/rage").speed(enemy, now, Balance.definition(category(enemy), enemy.kind, tuning), slow)

static func advance(combat, delta: float) -> void:
	for enemy in combat.enemies.duplicate():
		if enemy.dead: continue
		var stats: Dictionary = combat.resolved_definition(category(enemy), enemy.kind)
		for ability in ["rage", "regrowth", "summon"]:
			if has(enemy, ability, combat.tuning): Balance.Content.catalog().get_node("enemy_ability/" + ability).advance(combat, enemy, delta, stats)

static func summon(combat, enemy: Dictionary, stats: Dictionary) -> void:
	var count := 0
	for other in combat.enemies:
		if not other.dead and other.get("summoner", -1) == enemy.id: count += 1
	var remaining: Array[Vector2] = [enemy.pos]
	remaining.append_array(enemy.path.slice(enemy.segment))
	if remaining.size() < 2: return
	for index in range(maxi(0, mini(int(stats.escort_count), mini(int(stats.escort_limit) - count, 5000 - combat.enemies.size())))):
		var kind: String = Balance.ESCORT_KINDS[int(stats.escort_kind)]
		var escort: Dictionary = combat.spawn_on_path(kind, remaining)
		if escort.is_empty(): continue
		escort.summoner = enemy.id

static func retune(enemy: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var old := Balance.definition(category(enemy), enemy.kind, before)
	var next := Balance.definition(category(enemy), enemy.kind, after)
	for ability in ORDER:
		var field: String = {"shield": "shield", "wards": "wards", "regrowth": "regen", "summon": "toll"}.get(ability, "")
		if field.is_empty(): continue
		if not has(enemy, ability, after):
			enemy.erase(field)
			continue
		if not has(enemy, ability, before):
			Balance.Content.catalog().get_node("enemy_ability/" + ability).initialize(enemy, next)
			continue
		var stat: String = {"regen": "regen_period", "toll": "toll_period"}.get(field, field)
		var ratio := clampf(float(enemy.get(field, old[stat])) / maxf(0.0001, old[stat]), 0.0, 1.0)
		enemy[field] = next[stat] * ratio
		if field == "wards": enemy[field] = ceili(enemy[field])
