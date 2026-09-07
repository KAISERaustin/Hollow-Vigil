extends RefCounted

const Content = preload("res://scripts/content/registry.gd")
const Campaign = preload("res://scripts/campaign/run.gd")
const Director = preload("res://scripts/audio/audio_director.gd")

static func stages(kind: String) -> Array:
	return [[1, ""], [2, ""], [3, ""], [4, Balance.BRANCHES[kind].keys()[0]], [4, Balance.BRANCHES[kind].keys()[1]]]

static func live_fixture(t, kind: String, level: int = 1, branch: String = "") -> Dictionary:
	var game: VigilState = t.setup(kind, level, branch)
	var origin := VigilWorld.pad_position("0,0", 0)
	game.combat.authored_roads = [[origin + Vector2(-200, -30), origin + Vector2(200, -30)]]
	var victim: Dictionary = t.enemy(game, origin + Vector2(45, -30))
	victim.hp = 1000000.0
	victim.max_hp = victim.hp
	victim.stun_until = 1000.0
	return {"game": game, "enemy": victim, "origin": origin, "tower": game.data.towers["1"]}

static func run(t) -> void:
	cadence_and_audio(t)
	moving_targets(t)
	trap_targeting(t)
	gear_in_combat(t)
	campaign_and_portable_builds(t)
	component_families(t)

static func cadence_and_audio(t) -> void:
	var audio := Director.new()
	for kind in t.NewKinds:
		for stage in stages(kind):
			var f := live_fixture(t, kind, stage[0], stage[1])
			var events := []
			f.game.combat.sound_requested.connect(func(cue, _pos):
				if cue.begins_with("shot_"): events.append(f.game.combat.simulation_time)
			)
			for tick in range(240): f.game.combat.tick(Balance.STEP)
			var label := "%s/%s/%s" % [kind, stage[0], stage[1]]
			var stats := Balance.tower_stats(f.tower)
			t.check(events.size() >= 3 and f.enemy.hp < f.enemy.max_hp, label + " repeatedly attacks and damages through the real simulation")
			for index in range(1, events.size()):
				t.check(events[index] - events[index - 1] >= stats.period - 0.0001, label + " respects its attack interval")
			var voice: String = kind if stage[1].is_empty() else stage[1]
			for event in ["shot", "impact", "upgrade"]:
				var cue: String = event + "_" + voice
				t.check(Director.CATALOG.has(cue) and audio.load_stream(cue) != null, label + " has playable " + event + " audio")
			f.game.combat.sound_requested.get_connections().map(func(c): f.game.combat.sound_requested.disconnect(c.callable))
	audio.free()

static func moving_targets(t) -> void:
	for kind in ["ironspike", "moonwheel"]:
		for enemy_kind in ["basic", "fast", "heavy"]:
			for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				var f := live_fixture(t, kind)
				var victim: Dictionary = f.enemy
				victim.kind = enemy_kind
				victim.stun_until = 0.0
				victim.pos = f.origin + direction * 75.0
				victim.path = [victim.pos, victim.pos + direction.orthogonal() * 300.0]
				victim.segment = 1
				f.game.combat.tick(Balance.STEP)
				f.tower.cooldown = 100.0
				for tick in range(20): f.game.combat.tick(Balance.STEP)
				t.check(victim.hp < victim.max_hp, "%s leads moving %s from %s" % [kind, enemy_kind, direction])

static func trap_targeting(t) -> void:
	for mode in Balance.TARGET_MODES:
		var f := live_fixture(t, "caltrop_keep")
		f.game.combat.enemies.clear()
		f.game.combat.authored_roads = [[f.origin, f.origin + Vector2(200, 0)]]
		f.tower.target_mode = mode
		var victims := []
		for offset in [20, 70, 100]:
			var victim: Dictionary = t.enemy(f.game, f.origin + Vector2(offset, 0))
			victim.hp = 20000.0 if offset == 70 else 10000.0
			victim.path = [victim.pos, f.origin + Vector2(200, 0)]
			victim.stun_until = 100.0
			victims.append(victim)
		f.game.combat.tick(Balance.STEP)
		var selected: Dictionary = victims[{"first": 2, "last": 0, "most_hp": 1}[mode]]
		t.check(f.game.combat.traps.size() == 1 and f.game.combat.traps[0].pos.is_equal_approx(selected.pos), "Trap placement obeys " + mode)

static func gear_in_combat(t) -> void:
	for kind in t.NewKinds:
		for gear in Balance.GEAR:
			var f := live_fixture(t, kind, 3)
			f.game.combat.Relics.award(f.game.data, "90,90", gear)
			t.check(f.game.economy.equip_relic("1", "90,90", ""), kind + " equips " + gear)
			for tick in range(240): f.game.combat.tick(Balance.STEP)
			t.check(f.enemy.hp < f.enemy.max_hp and f.game.combat.relic_progress.has("1"), kind + " runs " + gear + " through actual attacks")
			f.game.economy.equip_relic("1", "", "90,90")
			t.check(not f.game.combat.relic_progress.has("1") and f.game.combat.line_projectiles.is_empty() and f.game.combat.traps.is_empty(), kind + " removes " + gear + " and owned transient state")
	# A returning blade must not create one ground field at every collision.
	for kind in ["ironspike", "moonwheel"]:
		var f := live_fixture(t, kind)
		f.game.combat.Relics.award(f.game.data, "90,90", "cinder_censer")
		f.game.economy.equip_relic("1", "90,90", "")
		f.game.set_balance_stat("gear", "cinder_censer", "attack_count", 1.0)
		f.enemy.hp = 10000.0
		var next: Dictionary = t.enemy(f.game, f.origin + Vector2(85, -30))
		next.stun_until = 100.0
		f.game.combat.tick(Balance.STEP)
		f.tower.cooldown = 100.0
		for tick in range(25): f.game.combat.tick(Balance.STEP)
		t.check(f.game.combat.effect_fields.size() == 1, kind + " creates one Censer field per launch across multiple contacts")

static func campaign_and_portable_builds(t) -> void:
	# Mission count comes from the authored campaign owner, not a fixed old count.
	var catalog = preload("res://scripts/campaign/catalog.gd")
	for index in range(catalog.COUNT):
		for kind in t.NewKinds:
			var campaign := Campaign.new(index, {}, "creative")
			campaign.game.data.balance = 100000.0
			var socket: int = campaign.mission.sockets[0].index
			t.check(campaign.build(socket, kind), "Campaign %d builds %s" % [index + 1, kind])
			var branch: String = Balance.BRANCHES[kind].keys()[index % 2]
			t.check(campaign.upgrade(socket) and campaign.upgrade(socket) and campaign.upgrade(socket, branch), "Campaign %d upgrades %s" % [index + 1, branch])
			var saved := campaign.checkpoint()
			t.check(Campaign.valid_checkpoint(saved) and Campaign.from_checkpoint(saved) != null, "Campaign %d saves %s" % [index + 1, branch])
			campaign.start_wave()
			for tick in range(60): campaign.tick(Balance.STEP)
			t.check(campaign.game.combat.simulation_time > 0.0, "Campaign %d simulates %s" % [index + 1, branch])
	for kind in t.NewKinds:
		for stage in stages(kind):
			var game: VigilState = t.setup(kind, stage[0], stage[1])
			var slots := VigilSaveSlots.new()
			var code := slots.export_build(game, "Tower expansion")
			var decoded := slots.decode_build(code)
			t.check(not decoded.is_empty() and decoded.towers["1"].kind == kind and int(decoded.towers["1"].level) == stage[0], kind + " portable build preserves stage " + str(stage))

static func component_families(t) -> void:
	var configurations := {
		"returning_attack": {"pierce_count": 3, "return_speed": 1.0},
		"orbit_attack": {},
		"road_traps": {"trap_capacity": 3, "trap_count": 1, "trap_duration": 8.0, "trap_arm_time": 0.5, "trap_radius": 12.0},
		"vulnerability_mark": {"vulnerability_percent": 12.0, "mark_duration": 2.0}}
	for ability in configurations:
		for kind in ["rapid", "heavy"]:
			var f := live_fixture(t, kind)
			var parent = Content.tower(kind)
			var slot := "mark" if ability == "vulnerability_mark" else "attack"
			var component = Content.catalog().get_node("attribute/" + ability)
			var assigned = parent.with_component(parent.id + "/test", slot, component, configurations[ability])
			f.game.combat.set_tower_definition("1", assigned)
			for tick in range(100): f.game.combat.tick(Balance.STEP)
			t.check(f.enemy.hp < f.enemy.max_hp, ability + " executes on assigned " + kind)
			if slot == "mark": t.check(f.game.combat.Relics.strength(f.enemy, "expose", f.game.combat.simulation_time) == 12.0, "Reusable mark reaches " + kind)
			f.game.combat.set_tower_definition("1", parent)
			t.check(f.game.combat.traps.is_empty() and f.game.combat.line_projectiles.is_empty() and parent.rule("components", []).is_empty(), ability + " removal leaves the parent and live state clean")
