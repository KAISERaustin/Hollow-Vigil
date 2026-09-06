extends "res://scripts/content/nodes/content_node.gd"

const ContentNode = preload("res://scripts/content/nodes/content_node.gd")

## Shared placement, instance construction and tier scaling for every tower type.
const Tuning = preload("res://scripts/content/catalogs/tuning.gd")

func can_place(socket_kind: String, owned: bool, occupied: bool) -> bool:
	return socket_kind == _rules.get("placement", "") and owned and not occupied

func can_equip(gear: ContentNode) -> bool:
	return gear != null and gear.is_a("gear") and gear.rule("slot") in _rules.get("equipment_slots", [])

func create(tower_id: String, region: String, pad: int) -> Dictionary:
	return make_record({"id": tower_id, "kind": _rules.get("base_kind", _rules.kind), "region": region, "pad": pad})

func _base_type() -> ContentNode:
	var cursor: ContentNode = self
	while cursor != null and cursor.rule("kind") != _rules.base_kind:
		cursor = cursor.parent
	return cursor

func valid_branch(branch: String) -> bool:
	return _rules.get("branches", {}).has(branch)

func scaled_stats(level: int, tuning: Dictionary = {}, branch: String = "") -> Dictionary:
	if _rules.has("base_kind"):
		return _base_type().scaled_stats(level, tuning, branch)
	var kind: String = _rules.kind
	var stats := definition(tuning)
	stats.targets = stats.get("targets", 1)
	var tier := clampi(level, 1, 3)
	if tier == 1:
		return stats
	var upgrade: Dictionary = _rules.upgrades[tier - 2]
	if upgrade.has("targets"):
		stats.targets = tuning.get("towers", {}).get(kind, {}).get("targets", upgrade.targets)
	for field in ["damage", "period", "range", "splash"]:
		var base: float = _attributes[field]
		if base > 0.0:
			stats[field] = upgrade[field] * (stats[field] / base)
	if level >= 4 and valid_branch(branch):
		var specialization: Dictionary = _rules.branches[branch]
		stats.name = specialization.name
		stats.description = specialization.description
		stats.color = specialization.color
		stats.merge(_rules.abilities[branch], true)
		for field in _rules.multipliers.get(branch, {}):
			stats[field] *= _rules.multipliers[branch][field]
	stats.period = clampf(stats.period, 0.1, Tuning.TUNING_FIELDS.towers.period.max)
	return stats

func stats(level: int = 0, tuning: Dictionary = {}, branch: String = "") -> Dictionary:
	if level == 0:
		level = int(_rules.get("level", 1))
	if _rules.has("base_kind"):
		return _base_type().stats(level, tuning, branch if branch != "" else _rules.get("branch", ""))
	var result := scaled_stats(level, tuning, branch)
	if level > 1:
		var key: String = _rules.kind + ":" + (branch if level == 4 else str(level))
		result.merge(tuning.get("towers", {}).get(key, {}), true)
	return result
