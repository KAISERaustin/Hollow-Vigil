extends "res://tests/test_runner.gd"
const Content = preload("res://scripts/content/registry.gd")

func full_tuning() -> Dictionary:
	var result := {}
	for category in Balance.TUNING_FIELDS:
		result[category] = {}
		for kind in Balance.definitions(category):
			result[category][kind] = {}
			for stat in Balance.fields_for(category, kind):
				var limits := Balance.field_limits(category, kind, stat)
				result[category][kind][stat] = limits.min
	return result

func benchmark() -> void:
	var full := full_tuning()
	var start := Time.get_ticks_usec()
	for iteration in 50:
		check(Balance.valid_tuning(full), "Full catalog tuning remains valid")
	print("TUNING_SCHEMA_BENCH: 50 full-catalog validations in %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))

func run() -> void:
	benchmark()
	if "--benchmark-only" in OS.get_cmdline_user_args():
		quit(0 if failures.is_empty() else 1)
		return
	var minima := full_tuning()
	var maxima := minima.duplicate(true)
	for category in maxima:
		for kind in maxima[category]:
			var fields := Balance.fields_for(category, kind)
			var priority: Array = []
			for stat in ["hp", "speed", "payout", "cost", "damage", "period", "range", "splash", "targets"]:
				if fields.has(stat): priority.append(stat)
			check(fields.keys().slice(0, priority.size()) == priority, "Primary editor field order: " + category + "/" + kind)
			for stat in fields:
				var limits: Dictionary = fields[stat]
				check(limits == Balance.field_limits(category, kind, stat), "Editor and validator expose identical limits: " + category + "/" + kind + "/" + stat)
				maxima[category][kind][stat] = limits.max
				check(not Balance.valid_tuning({category: {kind: {stat: limits.min - 1}}}) and not Balance.valid_tuning({category: {kind: {stat: limits.max + 1}}}), "Reject values outside every field's exact bounds: " + category + "/" + kind + "/" + stat)
				if limits.get("integer", false):
					check(not Balance.valid_tuning({category: {kind: {stat: limits.min + 0.5}}}), "Integer-only fields reject fractional values: " + category + "/" + kind + "/" + stat)
				if category == "towers" and kind.contains(":") and stat in ["cost", "damage", "range", "splash"]:
					var base: float = Balance.TOWERS[kind.get_slice(":", 0)][stat]
					var original: float = Balance.TUNING_FIELDS.towers[stat].max
					var expected: float = ceil(original * maxf(1.0, Balance.definitions(category)[kind][stat] / base)) + 1.0 if base > 0 else original
					check(limits.max == expected, "Tier ceiling preserves scaled legacy values: " + kind + "/" + stat)
	check(Balance.valid_tuning(minima) and Balance.valid_tuning(maxima), "Every supported minimum and maximum validates together")
	for invalid in [null, [], "text", 1, true, {"unknown": {}}, {"towers": []}, {"towers": {"unknown": {}}}, {"towers": {"rapid": []}}, {"towers": {"rapid": {"unknown": 1}}}, {"towers": {"rapid:2": {"slow_duration": 1}}}, {"towers": {"rapid": {"targets": 1.5}}}, {"enemies": {"basic": {"hp": true}}}, {"enemies": {"basic": {"hp": "5"}}}, {"enemies": {"basic": {"hp": NAN}}}, {"enemies": {"basic": {"hp": INF}}}, {"enemies": {"basic": {"hp": 0}}}, {"enemies": {"basic": {"hp": 100001}}}]:
		check(not Balance.valid_tuning(invalid), "Reject malformed tuning: " + str(invalid))
	check(Balance.valid_tuning({}) and Balance.valid_tuning({"towers": {"rapid": {}}}), "Empty overrides preserve defaults")
	var copied := Balance.fields_for("towers", "rapid:2")
	var ceiling: float = copied.damage.max
	copied.damage.max = -1
	check(Balance.field_limits("towers", "rapid:2", "damage").max == ceiling, "Returned limits cannot mutate future lookups")
	var retired: Dictionary = preload("res://scripts/content/catalogs/tuning.gd").RETIRED_FIELDS
	for category in retired:
		for kind in retired[category]:
			for stat in retired[category][kind]:
				var limits := Balance.field_limits(category, kind, stat)
				check(Balance.valid_tuning({category: {kind: {stat: limits.min}}}) and not Balance.editable_fields_for(category, kind).has(stat), "Retired persisted fields remain valid without reappearing in editor")
	# Register only inside this disposable runner; later calls must discover it.
	var registry := Content.catalog()
	var newcomer = registry.get_node("enemy/basic").derive("enemy/schema_probe", {"hp": 123.0}, {"kind": "schema_probe"})
	check(registry.register_node(newcomer, "enemies", "schema_probe"), "Attach a new subtype after all schema queries have run")
	check(Balance.fields_for("enemies", "schema_probe").has("hp") and Balance.valid_tuning({"enemies": {"schema_probe": {"hp": 123.0}}}), "Subsequent queries observe dynamic registration")
	print("TUNING SCHEMA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
