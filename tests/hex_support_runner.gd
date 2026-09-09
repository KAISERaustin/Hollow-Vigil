extends "res://tests/test_runner.gd"

func tower(g: VigilState, id: String, kind: String, pos: Vector2) -> Dictionary:
	var location := VigilWorld.ground_location(pos)
	var result := {"id": id, "kind": kind, "level": 1, "branch": "", "region": location.region, "pad": location.pad}
	g.data.towers[id] = result
	return result

func run() -> void:
	var g := VigilState.new(81)
	var hex := tower(g, "hex", "hex_lantern", Vector2.ZERO)
	var ally := tower(g, "ally", "rapid", Vector2(100, 0))
	var far := tower(g, "far", "heavy", Vector2(500, 0))
	check(is_equal_approx(g.combat.tower_stats(ally).damage, 6.48), "Nearby tower gains eight percent")
	check(g.combat.tower_stats(far).damage == 40.0, "Outside range is unchanged")
	check(g.combat.tower_stats(hex).damage == 1.0, "Aura excludes its own source")
	var second := tower(g, "second", "hex_lantern", Vector2(20, 0))
	second.level = 3
	check(is_equal_approx(g.combat.tower_stats(ally).damage, 6.72), "Strongest aura wins without stacking")
	g.data.towers.erase("second")
	check(is_equal_approx(g.combat.tower_stats(ally).damage, 6.48), "Selling source removes bonus immediately")
	var node = g.combat.TowerComponents.definition(g.combat, hex)
	g.combat.TowerComponents.set_definition(g.combat, hex.id, node.without_component("test/no-aura", "aura"))
	check(g.combat.tower_stats(ally).damage == 6.0, "Removing attachment removes bonus")
	var component = Balance.Content.catalog().find("attributes", "damage_aura")
	# Reassign the same capability to a different tower family.
	var other = g.combat.TowerComponents.definition(g.combat, ally)
	g.combat.TowerComponents.set_definition(g.combat, ally.id, other.with_component("test/support", "aura", component, {"aura_damage_percent": 10.0}))
	check(is_equal_approx(g.combat.tower_stats(hex).damage, 1.1), "Aura composes on another family")
	g.combat.TowerComponents.set_definition(g.combat, hex.id, null)
	var enemy := fixture_enemy(g)
	enemy.hp = 1000.0
	var stats := g.combat.tower_stats(hex)
	var shot := g.combat.Projectiles.make_shot(g.combat, hex, Vector2.ZERO, enemy, stats)
	g.combat.resolve_shot(shot, enemy)
	check(g.combat.Relics.strength(enemy, "expose", 0.0) == 75.0, "Real hit applies severe hex")
	check(g.combat.Relics.strength(enemy, "expose", 6.01) == 0.0, "Hex expires")
	check(fixture_enemy(g).get("gear_status", {}).is_empty(), "Unassigned enemy has independent state")
	for level in range(1, 5):
		var resolved := Balance.stats("hex_lantern", level, {}, "oathbrand" if level == 4 else "")
		check(resolved.damage == 1.0 and resolved.period >= 4.5, "Every tier remains slow and low damage")
	for tier in ["hex_lantern", "hex_lantern:2", "hex_lantern:3", "hex_lantern:oathbrand", "hex_lantern:witchlight"]:
		var fields := Balance.editable_fields_for("towers", tier)
		for key in ["cost", "damage", "period", "range", "vulnerability_percent", "mark_duration", "aura_damage_percent"]:
			check(fields.has(key), tier + " exposes " + key + " in Rules")
		if tier.ends_with("witchlight"):
			check(fields.has("mark_spread_count") and fields.has("mark_spread_radius"), "Spread controls are editable")
		var tuning := {"towers": {tier: {"aura_damage_percent": 17.0, "vulnerability_percent": 123.0, "mark_duration": 11.0, "period": 7.0, "damage": 2.0}}}
		var restored: Dictionary = JSON.parse_string(JSON.stringify(tuning))
		check(Balance.valid_tuning(restored), "Edited support settings survive serialization")
		var level := 1 if not tier.contains(":") else (int(tier.get_slice(":", 1)) if tier.get_slice(":", 1).is_valid_int() else 4)
		var branch: String = tier.get_slice(":", 1) if level == 4 else ""
		var resolved := Balance.stats("hex_lantern", level, restored, branch)
		check(resolved.aura_damage_percent == 17.0 and resolved.vulnerability_percent == 123.0 and resolved.mark_duration == 11.0 and resolved.period == 7.0 and resolved.damage == 2.0, "Every tier applies edited support values")
	g.data.settings.developer_balance = {"towers": {"hex_lantern": {"aura_damage_percent": 20.0}}}
	check(is_equal_approx(g.combat.tower_stats(ally).damage, 7.2), "Live rules edit updates aura immediately")
	print("HEX SUPPORT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
