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
	print("HEX SUPPORT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
