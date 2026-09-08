extends "res://scripts/content/nodes/content_node.gd"

const ContentNode = preload("res://scripts/content/nodes/content_node.gd")

## Shared placement, instance construction and tier scaling for every tower type.
const Tuning = preload("res://scripts/content/catalogs/tuning.gd")

func can_place(socket_kind: String, owned: bool, occupied: bool) -> bool:
	return socket_kind in ["plus", "ground"] and owned and not occupied

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
	var scaled := definition(tuning)
	scaled.targets = scaled.get("targets", 1)
	var tier := clampi(level, 1, 3)
	if tier == 1:
		return scaled
	var upgrade: Dictionary = _rules.upgrades[tier - 2]
	if upgrade.has("targets"):
		scaled.targets = tuning.get("towers", {}).get(kind, {}).get("targets", upgrade.targets)
	for field in ["damage", "period", "range", "splash"]:
		var base: float = _attributes[field]
		if base > 0.0:
			scaled[field] = upgrade[field] * (scaled[field] / base)
	# Component parameters are tier data too, with independent per-tier tuning.
	for field in upgrade:
		if field not in ["cost", "damage", "period", "range", "splash", "targets"]:
			scaled[field] = upgrade[field]
	if level >= 4 and valid_branch(branch):
		var specialization: Dictionary = _rules.branches[branch]
		scaled.name = specialization.name
		scaled.description = specialization.description
		scaled.color = specialization.color
		scaled.merge(_rules.abilities[branch], true)
		for field in _rules.multipliers.get(branch, {}):
			scaled[field] *= _rules.multipliers[branch][field]
	scaled.period = clampf(scaled.period, 0.1, Tuning.TUNING_FIELDS.towers.period.max)
	return scaled

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

func at_level(level: int, branch: String = "") -> ContentNode:
	if _rules.has("base_kind"):
		return self
	var node: ContentNode = self
	# Definitions are resolved by the owner so overrides remain run-local.
	if level >= 4 and valid_branch(branch):
		var attachments: Dictionary = _rules.get("branch_attachments", {}).get(branch, {})
		for slot in attachments:
			node = node.with_component(node.id + "/" + branch + "/" + slot, slot, attachments[slot])
	return node
