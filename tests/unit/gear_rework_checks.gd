extends RefCounted

const Gear = preload("res://tests/unit/gear_catalog_checks.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Content = preload("res://scripts/content/registry.gd")

static func run(t) -> void:
	ground(t)
	area_control(t)
	kill_stacks(t)
	range_and_blast(t)
	composition(t)
	persistence(t)
	campaign_cleanup(t)
	print("PASS GROUP: revised gear ground fields, area stun, kill stacks, range, splash and legacy saves")

static func neighbor(t, f: Dictionary, offset: Vector2) -> Dictionary:
	var enemy: Dictionary = t.fixture_enemy(f.game)
	enemy.pos = f.enemy.pos + offset
	enemy.hp = 10000.0
	enemy.max_hp = enemy.hp
	return enemy

static func ground(t) -> void:
	for tower_kind in Balance.TOWERS:
		var f := Gear.fixture(t, "cinder_censer", tower_kind)
		var near := neighbor(t, f, Vector2(40, 0))
		var far := neighbor(t, f, Vector2(46, 0))
		Gear.shoot(f)
		Gear.shoot(f)
		t.check(f.game.combat.effect_fields.is_empty(), "Censer waits for its third primary attack: " + tower_kind)
		var stats := Gear.shoot(f)
		t.check(f.game.combat.effect_fields.size() == 1, "One Censer field per impact, including splash: " + tower_kind)
		var before: float = near.hp
		var outside: float = far.hp
		f.game.combat.simulation_time = 1.0
		f.game.combat.EffectFields.advance(f.game.combat, 1.0)
		t.check(is_equal_approx(before - near.hp, stats.damage * 0.2), "Ground deals twenty percent per second inside radius: " + tower_kind)
		t.check(far.hp == outside and not f.enemy.has("gear_status"), "Ground stays at impact instead of attaching a wound")
		near.pos += Vector2(200, 0)
		before = near.hp
		f.game.combat.simulation_time = 2.0
		f.game.combat.EffectFields.advance(f.game.combat, 1.0)
		t.check(near.hp == before, "Leaving the field stops gear fire")
		f.game.combat.simulation_time = 4.0
		f.game.combat.EffectFields.advance(f.game.combat, 2.0)
		t.check(f.game.combat.effect_fields.is_empty(), "Ground expires at three seconds")
	var f := Gear.fixture(t, "cinder_censer")
	Gear.tune(f, {"attack_count": 1.0})
	Gear.shoot(f)
	f.enemy.pos += Vector2(10, 0)
	Gear.shoot(f)
	t.check(f.game.combat.effect_fields.size() == 2, "Distinct overlapping footprints retain their coverage")
	var before: float = f.enemy.hp
	f.game.combat.simulation_time = 0.5
	f.game.combat.EffectFields.advance(f.game.combat, 0.5)
	t.check(is_equal_approx(before - f.enemy.hp, 6.0 * 0.2 * 0.5), "A tower's overlapping fields do not stack damage")
	var second: String = f.game.economy.build("rapid", "0,0", 1)
	Relics.award(f.game.data, "91,90", "cinder_censer")
	f.game.economy.equip_relic(second, "91,90", "")
	var other := {"game": f.game, "tower": f.game.data.towers[second], "enemy": f.enemy}
	Gear.shoot(other)
	before = f.enemy.hp
	f.game.combat.simulation_time = 1.0
	f.game.combat.EffectFields.advance(f.game.combat, 0.5)
	t.check(is_equal_approx(before - f.enemy.hp, 6.0 * 0.2), "Different towers' ground fields contribute independently")
	Gear.launch(f)
	f.game.economy.equip_relic(f.tower.id, "", "90,90")
	f.game.combat.advance_shots(1.0)
	t.check(f.game.combat.effect_fields.all(func(field): return field.tower_id == second), "Unequip clears owned fields and blocks in-flight recreation")
	f.game.economy.sell(second)
	t.check(f.game.combat.effect_fields.is_empty(), "Selling the other owner removes only its fields")
	f = Gear.fixture(t, "cinder_censer")
	Gear.tune(f, {"attack_count": 1.0, "dot_multiplier": 1.0, "duration": 0.25})
	Gear.launch(f)
	Gear.tune(f, {"dot_multiplier": 10.0})
	f.game.combat.advance_shots(1.0)
	before = f.enemy.hp
	f.game.combat.simulation_time = 1.0
	f.game.combat.EffectFields.advance(f.game.combat, 1.0)
	t.check(is_equal_approx(before - f.enemy.hp, 6.0 * 0.25), "Traveling fields retain launch damage and tick only their remaining lifetime")

static func area_control(t) -> void:
	for tower_kind in Balance.TOWERS:
		var f := Gear.fixture(t, "bell_chime", tower_kind)
		var near := neighbor(t, f, Vector2(59, 0))
		var far := neighbor(t, f, Vector2(61, 0))
		var boss := neighbor(t, f, Vector2(20, 0))
		boss.boss = true
		boss.kind = "ruined_king"
		for attack in range(5): Gear.shoot(f)
		t.check(Relics.strength(near, "stun", 0.0) == 0, "Chime waits for sixth attack: " + tower_kind)
		Gear.shoot(f)
		t.check(Relics.strength(near, "stun", 0.49) > 0 and Relics.strength(near, "stun", 0.5) == 0, "Chime stuns nearby enemies for half a second: " + tower_kind)
		t.check(Relics.strength(boss, "stun", 0.19) > 0 and Relics.strength(boss, "stun", 0.2) == 0, "Area stun honors reduced boss duration")
		t.check(Relics.strength(far, "stun", 0.0) == 0, "Area control respects sixty-unit boundary")
		f.game.combat.simulation_time = 1.0
		for attack in range(6): Gear.shoot(f)
		t.check(Relics.strength(near, "stun", 1.0) == 0, "Shared target immunity prevents repeated area stun")
		f.game.combat.simulation_time = 3.0
		for attack in range(6): Gear.shoot(f)
		t.check(Relics.strength(near, "stun", 3.0) > 0, "Area stun returns when immunity expires")
		f.game.economy.equip_relic(f.tower.id, "", "90,90")
		t.check(Relics.strength(near, "stun", 3.0) == 0, "Unequip removes area recipients' statuses")

static func kill_stacks(t) -> void:
	for tower_kind in Balance.TOWERS:
		var f := Gear.fixture(t, "prior_rosary", tower_kind)
		var stats := Gear.shoot(f)
		Gear.shoot(f)
		t.check(stats.relic_damage_multiplier == 1.0 and Gear.shoot(f).relic_damage_multiplier == 1.0, "Hits alone do not grant Rosary damage: " + tower_kind)
		for count in range(1, 7):
			var victim := neighbor(t, f, Vector2(10, 0))
			f.game.combat.hit(victim, victim.hp, f.tower.id)
			f.game.combat.hit(victim, 10000, f.tower.id)
			stats = Relics.prepare(f.game.combat, f.tower, f.enemy, Balance.tower_stats(f.tower))
			t.check(is_equal_approx(stats.relic_damage_multiplier, 1.0 + mini(count, 5) * 0.05), "Each actual kill grants one capped stack: " + tower_kind)
		var different := neighbor(t, f, Vector2(20, 0))
		t.check(Relics.prepare(f.game.combat, f.tower, different, Balance.tower_stats(f.tower)).relic_damage_multiplier == 1.25, "Changing targets preserves kill stacks")
		f.game.combat.simulation_time = 5.9
		t.check(Gear.shoot(f).relic_damage_multiplier == 1.25, "Kill stacks last six seconds")
		f.game.combat.simulation_time = 6.0
		t.check(Gear.shoot(f).relic_damage_multiplier == 1.0, "Attacking cannot refresh the kill timer")
		f.game.combat.hit(different, different.hp, f.tower.id)
		f.game.combat.simulation_time = 11.0
		var victim := neighbor(t, f, Vector2(30, 0))
		f.game.combat.hit(victim, victim.hp, f.tower.id)
		f.game.combat.simulation_time = 12.0
		t.check(is_equal_approx(Gear.shoot(f).relic_damage_multiplier, 1.1), "A new kill refreshes existing stacks")
		var second: String = f.game.economy.build(tower_kind, "0,0", 1)
		f.game.economy.equip_relic(second, "90,90", "", f.tower.id)
		t.check(not f.game.combat.relic_progress.has(f.tower.id), "Transferring Rosary clears the old instance")
		t.check(Relics.prepare(f.game.combat, f.game.data.towers[second], f.enemy, Balance.tower_stats(f.game.data.towers[second])).relic_damage_multiplier == 1.0, "New owner starts without another tower's kill stacks")

static func range_and_blast(t) -> void:
	for tower_kind in Balance.TOWERS:
		for branch in [""] + Balance.BRANCHES[tower_kind].keys():
			var f := Gear.fixture(t, "matriarch_lantern", tower_kind)
			if branch != "":
				f.tower.level = 4
				f.tower.branch = branch
			var base := Balance.tower_stats(f.tower)
			var stats := Balance.tower_stats(f.tower, f.game.tuning, f.game.data.relics)
			t.check(is_equal_approx(stats.range, base.range * 1.2) and stats.period == base.period, "Lantern adds twenty percent reach on every tower and branch: " + tower_kind + "/" + branch)
			f.game.combat.scripted_spawns = true
			f.enemy.pos = VigilWorld.pad_position("0,0", 0) + Vector2(base.range * 1.1, 0)
			f.game.combat.tick(0.05)
			t.check(f.game.combat.relic_progress.has(f.tower.id), "Combat acquires targets beyond base range with Lantern")
			f.game.economy.equip_relic(f.tower.id, "", "90,90")
			t.check(Balance.tower_stats(f.tower, f.game.tuning, f.game.data.relics).range == base.range, "Unequipping immediately removes passive reach")
			f.game.combat.tick(0.05)
			t.check(not f.game.combat.target_locks.has(f.tower.id), "Out-of-range target locks are released")
	for level in [1, 2, 3, 4]:
		var f := Gear.fixture(t, "cinder_crucible", "splash")
		f.tower.level = level
		if level == 4: f.tower.branch = "cinderfield"
		var base := Balance.tower_stats(f.tower)
		var radius: float = maxf(52.0, base.splash * 1.25)
		var edge := neighbor(t, f, Vector2((base.splash + radius) * 0.5, 0))
		var far := neighbor(t, f, Vector2(radius + 1.0, 0))
		for attack in range(3): Gear.shoot(f)
		var before: float = edge.hp
		var outside: float = far.hp
		var stats := Gear.shoot(f)
		t.check(is_equal_approx(stats.relic_radius, radius) and is_equal_approx(before - edge.hp, base.damage), "Crucible extends actual splash beyond every Pyre tier")
		t.check(far.hp == outside, "Expanded blast retains its boundary")

static func composition(t) -> void:
	var stats := {"damage": 10.0, "period": 1.0, "range": 100.0, "splash": 20.0}
	var range_component = Content.catalog().get_node("attribute/range_bonus")
	var a = Content.gear("king_edge").with_component("gear/range_a", "reach", range_component, {"range_percent": 20.0})
	var b = Content.gear("king_signet").with_component("gear/range_b", "reach", range_component, {"range_percent": 50.0})
	t.check(a.modify_stats(stats).range == 120.0 and b.modify_stats(stats).range == 150.0 and stats.range == 100.0, "Shared passive component has isolated configuration and never mutates base stats")
	t.check(a.without_component("gear/no_reach", "reach").modify_stats(stats).range == 100.0 and Content.gear("king_edge").modify_stats(stats).range == 100.0, "Removing a passive leaves parent and sibling types unchanged")
	var kill_component = Content.catalog().get_node("attribute/kill_momentum")
	var config := {"damage_per_stack": 5.0, "stack_limit": 5.0, "stack_timeout": 6.0}
	a = Content.gear("king_edge").with_component("gear/kills_a", "kills", kill_component, config)
	b = Content.gear("king_signet").with_component("gear/kills_b", "kills", kill_component, config)
	var first: Dictionary = a.make_record()
	var second: Dictionary = a.make_record()
	var sibling: Dictionary = b.make_record()
	a.credited_kill(first, 0.0)
	t.check(a.prepare(first, 1, 0.0, stats).relic_damage_multiplier == 1.05 and a.prepare(second, 1, 0.0, stats).relic_damage_multiplier == 1.0 and b.prepare(sibling, 1, 0.0, stats).relic_damage_multiplier == 1.0, "Shared kill behavior isolates instances and assigned types")
	b.credited_kill(sibling, 0.0)
	t.check(b.prepare(sibling, 1, 0.0, stats).relic_damage_multiplier == 1.05, "Same kill component works on another assigned type")
	var removed = a.without_component("gear/no_kills", "kills")
	t.check(removed.prepare(first, 1, 0.1, stats).relic_damage_multiplier == 1.0 and not first.components.has("kills"), "Explicit kill-component removal discards its runtime counter")

static func persistence(t) -> void:
	var f := Gear.fixture(t, "matriarch_lantern")
	Gear.tune(f, {"range_percent": 35.0, "opening_attacks": 99.0, "opening_speed": 200.0, "reset_timeout": 1.0})
	t.check(Balance.valid_tuning(f.game.tuning) and Balance.editable_fields_for("gear", "matriarch_lantern").keys() == ["range_percent"], "Old Lantern settings remain readable but only reach is editable")
	f.game.save_path = "user://gear-rework.save"
	t.clean_test_save(f.game.save_path)
	t.check(f.game.save(1000), "New and retired gear settings save")
	var restored := VigilState.new()
	restored.save_path = f.game.save_path
	t.check(restored.load_save(1001), "Gear settings and ownership reload")
	var tower: Dictionary = restored.data.towers[f.tower.id]
	t.check(is_equal_approx(Balance.tower_stats(tower, restored.tuning, restored.data.relics).range, 140.0 * 1.35), "Saved Lantern range is effective after reload")
	t.check(restored.combat.relic_progress.is_empty() and restored.combat.effect_fields.is_empty(), "Temporary component state stays out of saved games")
	t.clean_test_save(f.game.save_path)

static func campaign_cleanup(t) -> void:
	var run = preload("res://scripts/campaign/run.gd").new(0)
	run.game.data.balance = 100000.0
	var socket: int = run.mission.sockets[0].index
	run.build(socket, "rapid")
	var id: String = run.tower_at(socket)
	Relics.award(run.game.data, "90,90", "cinder_censer")
	run.game.economy.equip_relic(id, "90,90", "")
	run.start_wave()
	run.next_spawn = run.schedule.size()
	var gear := Content.gear("cinder_censer")
	var prepared: Dictionary = {}
	var progress := gear.make_record()
	for index in range(3): prepared = gear.prepare(progress, 1, 0.0, Balance.tower_stats(run.game.data.towers[id]))
	prepared.gear_epoch = 0
	var entry: Dictionary = prepared.gear_effects[0]
	entry.attribute.arrive(run.game.combat, {"tower_id": id, "gear_epoch": 0, "base_damage": 6.0, "fx": {"pos": Vector2.ZERO}}, entry.config)
	t.check(run.game.combat.effect_fields.size() == 1, "Campaign owns a real ground field before transition")
	run.tick(0.05)
	t.check(run.phase == "planning" and run.game.combat.effect_fields.is_empty(), "Cleared campaign waves discard ground fields before the next wave")
