extends RefCounted
## Reusable wave composition operations. Proposals never mutate saved or live rules.
const Configuration = preload("res://scripts/campaign/configuration.gd")

static func waves(index: int, rules: Dictionary) -> Array:
	var mission := Configuration.resolve(index, rules)
	var result := []
	for wave in mission.waves.size():
		result.append({"groups": mission.waves[wave].duplicate(true), "reward": mission.wave_rules[wave].reward,
			"tuning": rules.get("waves", {}).get(str(wave), {}).get("tuning", {}).duplicate(true)})
	return result

static func replace(rules: Dictionary, entries: Array) -> Dictionary:
	var result := rules.duplicate(true)
	result.wave_count = entries.size()
	result.waves = {}
	for wave in entries.size(): result.waves[str(wave)] = entries[wave].duplicate(true)
	return result

static func append_wave(index: int, rules: Dictionary) -> Dictionary:
	var entries := waves(index, rules)
	var entry: Dictionary = entries[0].duplicate(true)
	entry.groups = []
	entries.append(entry)
	return replace(rules, entries)

static func remove_wave(index: int, rules: Dictionary, wave: int) -> Dictionary:
	var entries := waves(index, rules)
	if wave < 0 or wave >= entries.size(): return rules.duplicate(true)
	entries.remove_at(wave)
	return replace(rules, entries)

static func reset_wave(index: int, rules: Dictionary, wave: int) -> Dictionary:
	var entries := waves(index, rules)
	var defaults := waves(index, {})
	entries[wave] = defaults[wave if wave < defaults.size() else 0].duplicate(true)
	if wave >= defaults.size(): entries[wave].groups = []
	return replace(rules, entries)

static func default_group(index: int, kind: String) -> Array:
	var first: Array = Configuration.Catalog.level(index).waves[0][0]
	return [kind, 1, 0, first[3], first[4]]

static func set_count(index: int, rules: Dictionary, wave: int, kind: String, count: int) -> Dictionary:
	var entries := waves(index, rules)
	var groups: Array = entries[wave].groups
	var total := 0
	for group in groups:
		if group[0] == kind: total += int(group[1])
	if total == 0: return rules.duplicate(true)
	# Preserve each group's portal and timing; apportion a total across existing groups.
	var allocated := 0
	var cumulative := 0
	for group in groups:
		if group[0] != kind: continue
		cumulative += int(group[1])
		var target := int(round(float(count) * cumulative / total))
		group[1] = target - allocated
		allocated = target
	entries[wave].groups = groups.filter(func(group: Array): return int(group[1]) > 0)
	return replace(rules, entries)
