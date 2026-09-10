extends RefCounted

const Stats = preload("res://scripts/content/catalogs/stats.gd")

static func tower_node(node, key: String, tuning: Dictionary):
	var result = node
	for slot in ["attack", "mark", "aura", "boss_bonus"]: result = result.without_component(node.id + "/stats/" + slot, slot)
	for ability in Stats.Capabilities.TOWER:
		if not Stats.ability_enabled("towers", key, ability, tuning): continue
		var component = Balance.Content.catalog().find("attributes", ability)
		if component == null: continue
		var slot: String = {"vulnerability_mark": "mark", "damage_aura": "aura", "tower_boss_damage": "boss_bonus"}.get(ability, "attack")
		result = result.with_component(node.id + "/stats/" + ability, slot, component)
	return result

static func abilities(tower: Dictionary, tuning: Dictionary) -> Array:
	var result := []
	var key := Balance.tier_key(tower.kind, tower.level, tower.get("branch", ""))
	for ability in Stats.Capabilities.TOWER:
		if Stats.ability_enabled("towers", key, ability, tuning): result.append(ability)
	return result

static func has(tower: Dictionary, ability: String, tuning: Dictionary) -> bool:
	return Stats.ability_enabled("towers", Balance.tier_key(tower.kind, tower.level, tower.get("branch", "")), ability, tuning)

static func direct_gear(tower: Dictionary, tuning: Dictionary, inventory: Dictionary) -> Array:
	return []
