extends "res://tests/branch_runner.gd"
const Content = preload("res://scripts/content/registry.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const AfflictionArt = preload("res://scripts/rendering/effects/affliction_art.gd")

func fire(g: VigilState, target: Dictionary, id: String = "1", primary: bool = true) -> void:
	var tower: Dictionary = g.data.towers[id]
	var stats := Relics.prepare(g.combat, tower, target, Balance.tower_stats(tower, g.tuning))
	g.combat.launch_shot(tower, target.pos - Vector2(100, 0), target, stats, primary)
	g.combat.advance_shots(1.0)

func advance(g: VigilState, seconds: float) -> void:
	g.combat.simulation_time += seconds
	Relics.advance(g.combat, seconds)

func run() -> void:
	var g := fixture("rapid", "thorn_volley")
	var target := enemy(g)
	check(not AfflictionArt.poisoned(target, 0.0), "Unassigned enemy has no poison cue")
	fire(g, target)
	check(AfflictionArt.poisoned(target, 0.0), "Applied poison enables target cue")
	check(not AfflictionArt.poisoned(target, 3.0), "Poison cue ends exactly at expiry")
	check(not AfflictionArt.poisoned({"gear_status": {"burn": {"type": "dot", "damage": 5.0, "fire": true, "until": 3.0}}}, 0.0), "Fire damage does not display poison")
	check(target.hp == 9985.0 and target.gear_status.size() == 1, "Aimed hit deals direct damage and applies one poison")
	var poison: Dictionary = target.gear_status.values()[0]
	check(poison.damage == 5.0 and poison.until == 3.0 and not poison.fire, "Default poison deals five damage per second for three seconds")
	advance(g, 0.5)
	check(target.hp == 9982.5, "Partial simulation step deals proportional poison damage")
	fire(g, target)
	check(target.gear_status.size() == 1 and target.gear_status.values()[0].until == 3.5, "Repeated hits refresh instead of stacking")
	var before: float = target.hp
	advance(g, 4.0)
	check(target.hp == before - 15.0 and target.gear_status.is_empty(), "Expiration pays only remaining duration and clears status")
	var second := g.economy.build("rapid", "0,0", 1)
	g.economy.upgrade(second)
	g.economy.upgrade(second)
	g.economy.upgrade(second, 3, "thorn_volley")
	fire(g, target)
	advance(g, 0.5)
	fire(g, target, second)
	check(target.gear_status.size() == 2 and target.gear_status["1:ability/thorn_volley/damage_over_time"].until != target.gear_status[second + ":ability/thorn_volley/damage_over_time"].until, "Separate towers keep independent poison clocks")
	before = target.hp
	advance(g, 0.5)
	check(target.hp == before - 5.0, "Two assigned towers contribute independent damage")
	g = fixture("rapid", "thorn_volley")
	target = enemy(g)
	Relics.award(g.data, "90,90#warden_thornspindle", "warden_thornspindle")
	g.economy.equip_relic("1", "90,90#warden_thornspindle", "")
	g.set_balance_stat("gear", "warden_thornspindle", "attack_count", 1.0)
	fire(g, target)
	check(target.gear_status.size() == 2, "Equipment DOT and Poison Arrow use separate effect identities")
	g.economy.equip_relic("1", "", "90,90#warden_thornspindle")
	check(target.gear_status.size() == 1 and target.gear_status.values()[0].has("ability"), "Unequipping gear preserves tower poison")
	g.economy.sell("1")
	advance(g, 0.5)
	check(target.gear_status.is_empty(), "Selling source clears its poison")
	g = fixture("rapid", "thorn_volley")
	target = enemy(g)
	var tower: Dictionary = g.data.towers["1"]
	g.set_tower_tier_stat("rapid:thorn_volley", "duration", 4.0)
	g.set_tower_tier_stat("rapid:thorn_volley", "dot_multiplier", 2.0)
	g.combat.launch_shot(tower, Vector2(-100, 0), target, Balance.tower_stats(tower, g.tuning))
	g.set_tower_tier_stat("rapid:thorn_volley", "dot_multiplier", 3.0)
	g.combat.advance_shots(1.0)
	check(target.gear_status.values()[0].damage == 30.0 and target.gear_status.values()[0].until == 4.0, "In-flight poison retains launch configuration")
	fire(g, target)
	check(target.gear_status.size() == 1 and target.gear_status.values()[0].damage == 45.0, "Next hit refreshes using current balancing")
	var description := Balance.tower_description(Balance.tower_stats(tower, g.tuning))
	check(description.contains("45") and not description.contains("{") and not description.contains("fan"), "UI describes resolved poison statistics")
	var other := enemy(g)
	fire(g, other, "1", false)
	check(not other.has("gear_status"), "Secondary projectile does not duplicate poison")
	g.combat.launch_shot(tower, Vector2(-100, 0), target, Balance.tower_stats(tower, g.tuning))
	tower.branch = "frostneedle"
	g.combat.advance_shots(1.0)
	advance(g, 0.1)
	check(target.gear_status.is_empty(), "Replacing owning ability clears poison and blocks stale in-flight attachment")
	tower.branch = "thorn_volley"
	fire(g, target)
	var route: Array[Vector2] = [Vector2.ZERO, Vector2(100, 0)]
	Content.enemy("basic").create_into(target, 100, "-1,0", route, "forest")
	check(not target.has("gear_status"), "Enemy recycling clears all poison runtime state")
	g.set_tower_tier_stat("rapid:thorn_volley", "arrow_count", 7.0)
	g.set_tower_tier_stat("rapid:thorn_volley", "fan_angle", 1.2)
	g.save_path = "user://poison-compatibility-" + str(Time.get_ticks_usec()) + ".save"
	check(g.save(1000), "Stable branch and legacy fan settings remain valid saves")
	var restored := VigilState.new()
	restored.save_path = g.save_path
	check(restored.load_save(1001) and restored.data.towers["1"].branch == "thorn_volley" and Balance.tower_stats(restored.data.towers["1"], restored.tuning).name == "Poison Arrow", "Old branch identifier restores as Poison Arrow")
	check(restored.tuning.towers["rapid:thorn_volley"].arrow_count == 7.0 and restored.combat.enemies.all(func(e): return not e.has("gear_status")), "Saved compatibility values survive without runtime statuses")
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(g.save_path + suffix)
	composition()
	print("POISON ARROW: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func composition() -> void:
	var base := Content.ability("thorn_volley")
	var attribute := Content.catalog().get_node("attribute/damage_over_time")
	var first = base.with_component("ability/poison_test_a", "damage_over_time", attribute, {"duration": 1.0, "dot_multiplier": 1.0})
	var second = base.with_component("ability/poison_test_b", "damage_over_time", attribute, {"duration": 2.0, "dot_multiplier": 2.0})
	check(Content.catalog().register_node(first, "abilities", "poison_test_a") and Content.catalog().register_node(second, "abilities", "poison_test_b"), "Reusable attributes attach to independent ability definitions")
	for kind in ["rapid", "heavy"]:
		var g := fixture(kind, "")
		var target := enemy(g)
		g.data.towers["1"].branch = "poison_test_a" if kind == "rapid" else "poison_test_b"
		var damage: float = Balance.tower_stats(g.data.towers["1"]).damage
		fire(g, target)
		check(target.gear_status.size() == 1 and target.gear_status.values()[0].damage == damage * (1 if kind == "rapid" else 2), "Same component works through actual projectile pipeline on " + kind)
	var effects: Array = first.impact_effects({"damage": 10.0})
	var replaced = first.with_component(first.id, "damage_over_time", attribute, {"duration": 5.0})
	var removed = first.without_component(first.id, "damage_over_time")
	check(first.owns_effect(effects[0].config) and not replaced.owns_effect(effects[0].config) and not removed.owns_effect(effects[0].config), "Attachment replacement and removal invalidate captured effects")
	check(base.impact_effects({"damage": 10.0})[0].config.duration == 3.0 and Content.ability("frostneedle").impact_effects({}).is_empty(), "Reconfiguration leaves shared parent and unassigned abilities unchanged")
