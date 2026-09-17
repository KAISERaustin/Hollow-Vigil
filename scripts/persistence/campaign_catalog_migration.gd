extends RefCounted
## Revision 2 inserts three authored missions before each old chapter finale.
const REVISION := 2
const Levels = preload("res://scripts/content/catalogs/levels.gd")

static func index(old: int) -> int:
	return int(old / 5.0) * 8 + (7 if old % 5 == 4 else old % 5)

static func completed(old: int) -> int:
	return int(old / 5.0) * 8 + old % 5

static func level_entries(entries: Dictionary, raw_overrides: bool = false) -> Dictionary:
	var result := {}
	for key in entries:
		if not key is String or not key.is_valid_int() or str(int(key)) != key or int(key) < 0 or int(key) >= 30: return {}
		var mapped := index(int(key))
		if not entries[key] is Dictionary: return {}
		var entry: Variant = entries[key].duplicate(true)
		if not entry is Dictionary: return {}
		if not raw_overrides and entry.has("overrides") and not entry.overrides is Dictionary: return {}
		var rules: Dictionary = entry if raw_overrides else entry.get("overrides", {})
		# Preserve the old wave count when a mission's teaching balance changed.
		if rules.has("waves") and not rules.has("wave_count"):
			rules.wave_count = Levels.MISSIONS[mapped].waves.size()
		result[str(mapped)] = entry
	return result

static func document(source: Dictionary, kind: String) -> Dictionary:
	if source.get("catalog_revision", 1) == REVISION: return source
	if source.has("catalog_revision"): return {}
	var value := source.duplicate(true)
	value.catalog_revision = REVISION
	if kind in ["slot", "progress"]:
		var field := "completed" if kind == "slot" else "completed_levels"
		var amount: Variant = value.get(field, 0)
		if not (amount is int or amount is float) or amount != int(amount) or amount < 0 or amount > 30: return {}
		value[field] = completed(int(amount))
		var beaten := []
		if not value.get("beaten_levels", []) is Array: return {}
		var current: Variant = value.get("current_level", -1)
		if not (current is int or current is float) or current != int(current) or current < -1 or current >= 30: return {}
		for old in value.get("beaten_levels", []):
			if not (old is int or old is float) or old != int(old) or old < 0 or old >= 30: return {}
			beaten.append(index(int(old)))
		value.beaten_levels = beaten
		value.current_level = mini(int(value[field]), 47)
	if value.has("levels"):
		if not value.levels is Dictionary: return {}
		var mapped := level_entries(value.levels, kind == "configuration")
		if mapped.is_empty() and not value.levels.is_empty(): return {}
		value.levels = mapped
	if kind == "level":
		if not value.get("level") is float and not value.get("level") is int: return {}
		if value.level != int(value.level) or value.level < 0 or value.level >= 30: return {}
		value.level = index(int(value.level))
	if kind == "slot" and value.get("checkpoint", {}) is Dictionary and not value.checkpoint.is_empty():
		var checkpoint_level: Variant = value.checkpoint.get("level")
		if not (checkpoint_level is int or checkpoint_level is float) or checkpoint_level != int(checkpoint_level) or checkpoint_level < 0 or checkpoint_level >= 30: return {}
		value.checkpoint.level = index(int(value.checkpoint.level))
	return value
