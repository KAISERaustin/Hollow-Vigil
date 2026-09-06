extends RefCounted

const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Content = preload("res://scripts/content/registry.gd")

static func run(t) -> void:
	catalog_and_save(t)
	composition(t)
	new_effects(t)
	lifecycle(t)
	print("PASS GROUP: eighteen boss gear types, tunable effects, composition, cleanup and persistence")

static func fixture(t, kind: String, tower_kind: String = "rapid") -> Dictionary:
	var game: VigilState = t.legacy_core_fixture(879)
	game.data.balance = 100000.0
	var id := game.economy.build(tower_kind, "0,0", 0)
	Relics.award(game.data, "90,90", kind)
	game.economy.equip_relic(id, "90,90", "")
	var enemy: Dictionary = t.fixture_enemy(game)
	game.set_balance_stat("enemies", "basic", "hp", 10000.0)
	var route: Array[Vector2] = [Vector2.ZERO, Vector2(500, 0)]
	enemy.path = route
	enemy.segment = 1
	enemy.pos = Vector2(250, 0)
	return {"game": game, "tower": game.data.towers[id], "enemy": enemy}

static func launch(f: Dictionary) -> Dictionary:
	var stats := Relics.prepare(f.game.combat, f.tower, f.enemy, Balance.tower_stats(f.tower, f.game.tuning))
	f.game.combat.launch_shot(f.tower, f.enemy.pos, f.enemy, stats)
	return stats

static func shoot(f: Dictionary) -> Dictionary:
	var stats := launch(f)
	f.game.combat.advance_shots(5.0)
	return stats

static func tune(f: Dictionary, values: Dictionary) -> void:
	for stat in values:
		f.game.set_balance_stat("gear", Relics.kind(f.game.data, f.tower), stat, values[stat])

static func catalog_and_save(t) -> void:
	t.check(Balance.GEAR.size() == 18, "Exactly eighteen gear types ship")
	var seen := {}
	var game: VigilState = t.legacy_core_fixture(879)
	for boss in Balance.BOSSES:
		var drops: Array = Relics.BOSS_DROPS[boss]
		t.check(drops.size() == 3 and Content.boss(boss).rule("drops") == drops, "Three registered drops per boss: " + boss)
		var source := str(seen.size() + 90) + ",90"
		t.check(Relics.award_set(game.data, source, boss).size() == 3, "Victory awards complete set")
		t.check(Relics.award_set(game.data, source, boss).is_empty(), "Repeated award is idempotent")
		for kind in drops:
			t.check(not seen.has(kind), "Gear belongs to exactly one boss")
			seen[kind] = true
			var values: Dictionary = Balance.GEAR[kind]
			t.check(not Content.gear(kind).rule("components").is_empty(), "Gear attaches real behavior: " + kind)
			t.check(Relics.DEFINITIONS[kind].boss == boss and not Relics.description(kind).contains("{"), "Description and provenance resolve: " + kind)
			for stat in values:
				if not values[stat] is float and not values[stat] is int:
					continue
				t.check(stat in Balance.fields_for("gear", kind), "Every numeric detail has a control: " + kind + "/" + stat)
				var limits := Balance.field_limits("gear", kind, stat)
				for value in [limits.min, limits.max, values[stat]]:
					t.check(game.set_balance_stat("gear", kind, stat, value), "Accept bounds/default: " + kind + "/" + stat)
				t.check(not game.set_balance_stat("gear", kind, stat, NAN), "Reject nonfinite gear values")
			var first_stat: String = Balance.fields_for("gear", kind).keys()[0]
			game.set_balance_stat("gear", kind, first_stat, Balance.field_limits("gear", kind, first_stat).max)
	t.check(game.storage.valid_data(game.snapshot(1000)), "All eighteen owned gear types and edited settings validate")
	game.save_path = "user://gear-catalog.save"
	t.clean_test_save(game.save_path)
	t.check(game.save(1000), "Save every gear type")
	var restored := VigilState.new()
	restored.save_path = game.save_path
	t.check(restored.load_save(1001) and restored.data.relics == game.data.relics, "All gear IDs survive disk reload")
	t.check(preload("res://tests/unit/developer_tier_checks.gd").same_values(restored.tuning, game.tuning), "Every gear override survives reload")
	var invalid := game.snapshot(1000)
	invalid.relics["90,90#unknown"] = "warden"
	t.check(not game.storage.valid_data(invalid), "Reject mismatched compound gear identities")
	t.clean_test_save(game.save_path)

static func composition(t) -> void:
	var component = Content.catalog().get_node("attribute/momentum_speed")
	var config := {"speed_per_stack": 20.0, "stack_limit": 3.0, "stack_timeout": 2.0}
	var first = Content.gear("king_edge").with_component("gear/prototype_a", "haste", component, config)
	var second = Content.gear("king_signet").with_component("gear/prototype_b", "haste", component, config)
	var a: Dictionary = first.make_record()
	var b: Dictionary = second.make_record()
	var stats := {"damage": 10.0, "period": 1.0}
	first.prepare(a, 1, 0.0, stats)
	var charged: Dictionary = first.prepare(a, 1, 0.1, stats)
	t.check(charged.period < 1.0 and second.prepare(b, 1, 0.1, stats).period == 1.0, "Shared attribute works on multiple recipients with isolated progress")
	var reconfigured = first.with_component("gear/reconfigured", "haste", component, config.merged({"speed_per_stack": 30.0}, true))
	t.check(reconfigured.prepare(a, 1, 0.2, stats).period == 1.0, "Explicit replacement by the same object with new configuration resets instance state")
	t.check(Content.gear("king_edge").prepare(Content.gear("king_edge").make_record(), 1, 0.1, stats).period == 1.0, "Attaching does not mutate unassigned original")
	var removed = first.without_component("gear/removed", "haste")
	t.check(removed.prepare(a, 1, 0.2, stats).period == 1.0 and not a.components.has("haste"), "Explicit removal clears only removed component state")
	var replaced = second.with_component("gear/replaced", "haste", Content.catalog().get_node("attribute/opening"), {"opening_attacks": 1.0, "opening_speed": 100.0, "reset_timeout": 1.0})
	t.check(replaced.prepare(b, 2, 0.2, stats).period == 0.5 and not b.components.haste.state.has("stacks"), "Replacement discards the previous attribute's progress")
	t.check(Content.gear("warden_thornspindle").rule("components")[0].component == Content.gear("cinder_censer").rule("components")[0].component, "Bleed and fire reuse the same configured damage-over-time object")

static func new_effects(t) -> void:
	for kind in ["warden_thornspindle", "cinder_censer"]:
		var f := fixture(t, kind)
		tune(f, {"attack_count": 1.0, "dot_multiplier": 2.0, "duration": 0.25})
		var stats := shoot(f)
		var before: float = f.enemy.hp
		f.game.combat.simulation_time = 1.0
		Relics.advance(f.game.combat, 1.0)
		t.check(is_equal_approx(before - f.enemy.hp, stats.damage * 0.5), "DOT uses edited rate and only remaining lifetime: " + kind)
		t.check(f.enemy.gear_status.is_empty(), "Expired DOT removes runtime state")
	var f := fixture(t, "warden_lens")
	tune(f, {"damage_multiplier": 3.0})
	f.enemy.root_until = 2.0
	var stats := shoot(f)
	t.check(f.enemy.max_hp - f.enemy.hp == stats.damage * 3, "Lens rewards a real control effect")
	for kind in ["ruined_king", "king_signet", "king_edge"]:
		f = fixture(t, kind)
		tune(f, {"damage_multiplier": 3.0})
		if kind == "ruined_king":
			# A zero-defense boss isolates the condition from shield absorption.
			f.enemy.boss = true
			f.enemy.kind = "ruined_king"
		elif kind == "king_edge":
			f.enemy.hp = 2000.0
		var before: float = f.enemy.hp
		stats = shoot(f)
		t.check(before - f.enemy.hp == stats.damage * 3, "Conditional damage applies: " + kind)
		f.enemy.erase("boss")
		f.enemy.kind = "basic"
		f.enemy.hp = 5000.0
		before = f.enemy.hp
		shoot(f)
		t.check(before - f.enemy.hp == stats.damage, "Conditional damage leaves nonqualifying targets unchanged: " + kind)
	f = fixture(t, "prior_rosary")
	tune(f, {"damage_per_stack": 50.0, "stack_limit": 2.0})
	shoot(f)
	shoot(f)
	var before: float = f.enemy.hp
	stats = shoot(f)
	t.check(before - f.enemy.hp == stats.damage * 2, "Rosary reaches edited damage stack limit")
	f = fixture(t, "matriarch_lantern")
	tune(f, {"opening_attacks": 1.0, "opening_speed": 100.0, "reset_timeout": 1.0})
	stats = shoot(f)
	t.check(stats.period * 2 == Balance.tower_stats(f.tower).period and shoot(f).period == Balance.tower_stats(f.tower).period, "Lantern spends opening burst then returns to normal")
	f.game.combat.simulation_time = 1.0
	t.check(shoot(f).period == stats.period, "Lantern burst resets after edited idle duration")
	f = fixture(t, "bell_chain")
	tune(f, {"attack_count": 1.0, "push_distance": 20.0, "push_immunity": 2.0})
	var position: Vector2 = f.enemy.pos
	shoot(f)
	t.check(is_equal_approx(position.distance_to(f.enemy.pos), 20.0), "Chain moves target backward by edited distance")
	position = f.enemy.pos
	shoot(f)
	t.check(f.enemy.pos == position, "Chain respects shared knockback immunity")
	for kind in ["mourning_matriarch", "bell_chime", "matriarch_fruit"]:
		f = fixture(t, kind)
		tune(f, {"attack_count": 1.0, "duration": 2.0})
		stats = shoot(f)
		var type: String = {"mourning_matriarch": "slow", "bell_chime": "stun", "matriarch_fruit": "expose"}[kind]
		t.check(Relics.strength(f.enemy, type, 0.0) > 0 and Relics.strength(f.enemy, type, 2.0) == 0, "Timed effect honors duration: " + kind)
		if kind == "matriarch_fruit":
			before = f.enemy.hp
			f.game.combat.hit(f.enemy, 100.0, f.tower.id)
			t.check(is_equal_approx(before - f.enemy.hp, 115.0), "Exposure amplifies actual incoming combat damage")
	for kind in ["cinder_crucible", "prior_mirror"]:
		f = fixture(t, kind)
		tune(f, {"attack_count": 1.0})
		var other: Dictionary = t.fixture_enemy(f.game)
		other.pos = f.enemy.pos + Vector2(15, 0)
		other.hp = 10000.0
		var distant: Dictionary = t.fixture_enemy(f.game)
		distant.pos = f.enemy.pos + Vector2(400, 0)
		var original: float = distant.hp
		shoot(f)
		t.check(other.hp < 10000.0 and distant.hp == original, "Area effect hits nearby target and respects radius: " + kind)
		t.check(not other.has("gear_status") and f.game.combat.pending_shots.is_empty(), "Secondary effects do not recurse")

static func lifecycle(t) -> void:
	for kind in ["warden", "mourning_matriarch", "bell_chime", "matriarch_fruit", "cinder_censer"]:
		var f := fixture(t, kind)
		if Balance.GEAR[kind].has("attack_count"):
			tune(f, {"attack_count": 1.0})
		shoot(f)
		t.check(not f.enemy.get("gear_status", {}).is_empty(), "Equipped component creates owned status")
		launch(f)
		f.game.economy.equip_relic(f.tower.id, "", "90,90")
		f.game.combat.advance_shots(5.0)
		t.check(f.enemy.get("gear_status", {}).is_empty() and not f.game.combat.relic_progress.has(f.tower.id), "Unequip clears effects and prevents an in-flight shot reattaching them: " + kind)
		t.check(f.enemy.get("root_until", 0.0) == 0.0, "Removed roots do not keep enemies immobilized")
		var route: Array[Vector2] = [Vector2.ZERO, Vector2(100, 0)]
		Content.enemy("basic").create_into(f.enemy, 100, "-1,0", route, "forest")
		t.check(not f.enemy.has("gear_status") and not f.enemy.has("gear_stun_immune_until"), "Pooling resets attached enemy effects and immunity")
	var f := fixture(t, "cinder_censer")
	tune(f, {"attack_count": 1.0, "dot_multiplier": 1.0})
	launch(f)
	tune(f, {"dot_multiplier": 10.0})
	f.game.combat.advance_shots(5.0)
	var status: Dictionary = f.enemy.gear_status.values()[0]
	t.check(status.damage == Balance.tower_stats(f.tower).damage, "In-flight effect retains launch configuration across a live edit")
