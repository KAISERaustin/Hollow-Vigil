extends RefCounted

const Stats = preload("res://scripts/content/catalogs/stats.gd")

## Flatten legacy base-tier scaling exactly once, before new independent edits.
static func tuning(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	if not source.has("towers"): return result
	for key in Stats.Frozen.VALUES.towers:
		if not key.contains(":"): continue
		var base: String = key.get_slice(":", 0)
		var edits: Dictionary = source.towers.get(base, {})
		if edits.is_empty(): continue
		if not result.towers.has(key): result.towers[key] = {}
		for field in ["cost", "damage", "period", "range", "splash", "targets"]:
			if not edits.has(field) or result.towers[key].has(field): continue
			var original: float = Stats.Frozen.VALUES.towers[base].get(field, 0.0)
			if field == "targets": result.towers[key][field] = edits[field]
			elif original > 0.0:
				result.towers[key][field] = Stats.Frozen.VALUES.towers[key][field] * float(edits[field]) / original
				if field == "cost": result.towers[key][field] = ceil(result.towers[key][field])
	return result

## The slot owns one entity rule set. Level/wave resources remain independent.
static func levels(source: Dictionary, migrate: bool = false) -> Dictionary:
	var result := source.duplicate(true)
	var global := {}
	for index in range(30):
		var rules: Dictionary = source.get(str(index), {}).get("overrides", {})
		var candidate: Dictionary = rules.get("tuning", {}).duplicate(true)
		# Historical first-Warden reductions are explicitly retired by the user.
		if index == 4 and candidate.get("bosses", {}).get("warden", {}) == {"hp": 1800.0, "shield": 300.0, "regen_period": 12.0}:
			candidate.bosses.erase("warden")
		if migrate: candidate = tuning(candidate)
		for category in Stats.CATEGORIES:
			if not global.has(category): global[category] = {}
			for kind in candidate.get(category, {}):
				if not global[category].has(kind): global[category][kind] = candidate[category][kind].duplicate(true)
	for index in range(30):
		var key := str(index)
		if not result.has(key): result[key] = {"overrides": {}}
		var rules: Dictionary = result[key].overrides
		if not rules.has("tuning"): rules.tuning = {}
		for category in Stats.CATEGORIES:
			if global[category].is_empty(): rules.tuning.erase(category)
			else: rules.tuning[category] = global[category].duplicate(true)
		for wave in rules.get("waves", {}).values():
			for category in Stats.CATEGORIES: wave.get("tuning", {}).erase(category)
	return result
