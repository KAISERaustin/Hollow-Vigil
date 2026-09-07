extends "res://tests/branch_runner.gd"

const NewKinds := ["ironspike", "moonwheel", "hex_lantern", "caltrop_keep"]
const Lines = preload("res://scripts/gameplay/combat/line_projectiles.gd")
const Traps = preload("res://scripts/gameplay/combat/road_traps.gd")
const Campaign = preload("res://scripts/campaign/run.gd")

func setup(kind: String, tier: int = 1, branch: String = "") -> VigilState:
	var g := fixture(kind, "")
	g.data.towers["1"].level = tier
	if not branch.is_empty(): g.data.towers["1"].branch = branch
	g.combat.scripted_spawns = true
	g.combat.authored_roads = [[Vector2(-250, -30), Vector2(250, -30)]]
	g.combat.TowerComponents.sync(g.combat)
	return g

func fire_component(g: VigilState, target: Dictionary = {}) -> void:
	var tower: Dictionary = g.data.towers["1"]
	var stats := Balance.tower_stats(tower, g.tuning, g.data.relics)
	var entry: Dictionary = g.combat.TowerComponents.attack_entry(g.combat, tower, stats)
	var prepared := g.combat.Relics.prepare(g.combat, tower, {"id": -1} if target.is_empty() else target, entry.config)
	entry.component.attack(g.combat, tower, Vector2.ZERO, target, prepared)

func mark(g: VigilState, target: Dictionary, id: String = "1") -> void:
	var tower: Dictionary = g.data.towers[id]
	g.combat.launch_shot(tower, Vector2.ZERO, target, Balance.tower_stats(tower, g.tuning, g.data.relics))
	g.combat.advance_shots(1.0)

func run() -> void:
	transactions()
	piercing()
	returning_blades()
	vulnerability()
	road_traps()
	composition()
	print("TOWER EXPANSION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func transactions() -> void:
	check(Balance.TOWERS.size() == 8, "Eight tower families are in the shared build catalog")
	for kind in NewKinds:
		for branch in Balance.BRANCHES[kind]:
			var g := setup(kind)
			check(g.storage.valid_data(g.data), kind + " base save is valid")
			for tier in [2, 3, 4]:
				check(g.economy.upgrade("1", tier - 1, branch if tier == 4 else ""), kind + " upgrades to " + str(tier))
				var stats := Balance.tower_stats(g.data.towers["1"])
				check(not Balance.tower_description(stats).contains("{"), kind + " describes every resolved parameter")
				var key := Balance.tier_key(kind, tier, branch)
				for field in Balance.editable_fields_for("towers", key):
					var values := {"towers": {key: {field: Balance.definitions("towers")[key][field]}}}
					check(Balance.valid_tuning(values), key + " default is valid editable tuning: " + field)
			check(not g.economy.upgrade("1", 4, branch), "No fifth level for " + branch)
			g.save_path = "user://tower-expansion-" + branch + ".save"
			check(g.save(1000), "Save " + branch)
			var data := g.storage.read_candidate(g.save_path)
			check(data.towers["1"].branch == branch, "Roundtrip " + branch)
			check(g.economy.relocate("1", "0,0", 1), "Move " + branch)
			check(g.economy.sell("1").refund > 0, "Sell " + branch)
			var campaign := Campaign.new(0, {}, "creative")
			campaign.game.data.balance = 100000.0
			var socket: int = campaign.mission.sockets[0].index
			check(campaign.build(socket, kind), "Campaign builds " + kind)
			check(campaign.upgrade(socket) and campaign.upgrade(socket) and campaign.upgrade(socket, branch), "Campaign progression " + branch)
			check(campaign.game.storage.valid_data(campaign.game.data), "Campaign tower data valid " + branch)

func piercing() -> void:
	var g := setup("ironspike")
	var victims := []
	for x in [60, 100, 140, 180]: victims.append(enemy(g, Vector2(x, -30)))
	var off_lane := enemy(g, Vector2(90, 0))
	fire_component(g, victims[0])
	check(victims[0].hp == 10000.0, "Piercing launch deals no early damage")
	Lines.advance(g.combat, 1.0)
	check(is_equal_approx(victims[0].hp, 9978.0) and is_equal_approx(victims[1].hp, 9984.6) and is_equal_approx(victims[2].hp, 9989.0), "Piercing resolves ordered 100/70/50 percent damage")
	check(victims[3].hp == 10000.0 and off_lane.hp == 10000.0, "Pierce cap and lane collision exclude other enemies")
	check(g.combat.line_projectiles.is_empty(), "Completed straight projectile expires")
	g = setup("ironspike", 4, "needle_battery")
	var target := enemy(g, Vector2(90, -30))
	g.set_tower_tier_stat("ironspike:needle_battery", "projectile_width", 40.0)
	fire_component(g, target)
	check(g.combat.line_projectiles.size() == 3, "Battery launches three parallel projectiles")
	Lines.advance(g.combat, 1.0)
	print("BATTERY DEBUG hp=", target.hp, " stats=", Balance.tower_stats(g.data.towers["1"], g.tuning))
	check(is_equal_approx(target.hp, 9972.0), "Overlapping volley hits one victim only once")
	g = setup("ironspike", 4, "siegebreaker")
	target = enemy(g, Vector2(60, -30))
	var stats := Balance.tower_stats(g.data.towers["1"])
	var shot := g.combat.Projectiles.make_shot(g.combat, g.data.towers["1"], Vector2.ZERO, target, stats)
	var boss := {"boss": true}
	g.combat.TowerComponents.before_hit(g.combat, shot, boss)
	check(is_equal_approx(shot.damage, 90.0), "Siegebreaker boss modifier applies before shared defenses")

func returning_blades() -> void:
	var g := setup("moonwheel")
	var victim := enemy(g, Vector2(70, -32))
	fire_component(g, victim)
	var entry: Dictionary = g.combat.TowerComponents.attack_entry(g.combat, g.data.towers["1"], Balance.stats("moonwheel", 1))
	check(not entry.component.ready(g.combat, g.data.towers["1"], Vector2.ZERO, entry.config), "Only one returning blade is in flight")
	Lines.advance(g.combat, 0.3)
	check(victim.hp == 9990.0, "Outward contact damages once")
	Lines.advance(g.combat, 1.0)
	check(victim.hp == 9980.0 and g.combat.line_projectiles.is_empty(), "Return contact damages once and releases blade")
	g = setup("moonwheel", 4, "reaper_wheel")
	victim = enemy(g, Vector2(70, -32))
	fire_component(g, victim)
	Lines.advance(g.combat, 2.0)
	check(victim.hp == 9936.0, "Reaper retains both passes with upgraded damage")
	g = setup("moonwheel", 4, "orbit_crown")
	victim = enemy(g, Vector2(40, 0))
	var outside := enemy(g, Vector2(90, 0))
	fire_component(g, victim)
	check(victim.hp == 9988.0 and outside.hp == 10000.0, "Orbit sweep deals one hit in short range, not three blade hits")

func vulnerability() -> void:
	var g := setup("hex_lantern")
	var target := enemy(g, Vector2(60, 0))
	mark(g, target)
	check(target.hp == 9996.0 and g.combat.Relics.strength(target, "expose", 0.0) == 12.0, "Base mark applies after its own damage")
	var ally := g.economy.build("heavy", "0,0", 1)
	g.combat.hit(target, 100.0, ally)
	check(is_equal_approx(target.hp, 9884.0), "Another tower benefits from vulnerability")
	var second := g.economy.build("hex_lantern", "0,0", 2)
	g.economy.upgrade(second)
	g.economy.upgrade(second)
	g.economy.upgrade(second, 3, "oathbrand")
	mark(g, target, second)
	check(g.combat.Relics.strength(target, "expose", 0.0) == 35.0 and target.gear_status.size() == 2, "Strongest mark wins with independent sources")
	g.economy.sell(second)
	check(g.combat.Relics.strength(target, "expose", 0.0) == 12.0, "Removing stronger source reveals the weaker mark")
	g.combat.simulation_time = 2.0
	g.combat.Relics.advance(g.combat, 2.0)
	check(target.gear_status.is_empty(), "Mark expires exactly at its duration")
	g = setup("hex_lantern", 4, "witchlight")
	target = enemy(g, Vector2(60, 0))
	var next := enemy(g, Vector2(80, 0))
	var distant := enemy(g, Vector2(160, 0))
	mark(g, target)
	g.combat.hit(target, 100000.0, "1")
	check(g.combat.Relics.strength(next, "expose", 0.0) == 20.0 and not next.gear_status.values()[0].direct, "Witchlight spreads on directly marked death")
	g.combat.hit(next, 100000.0, "1")
	check(not distant.has("gear_status"), "A propagated mark never spreads a second generation")

func road_traps() -> void:
	var g := setup("caltrop_keep")
	fire_component(g)
	check(g.combat.traps.size() == 1, "Trap deploys onto an authored road without a target")
	var pos: Vector2 = g.combat.traps[0].pos
	var victim := enemy(g, pos)
	Traps.advance(g.combat)
	check(victim.hp == 10000.0, "Unarmed trap cannot hit")
	g.combat.simulation_time = 0.5
	Traps.advance(g.combat)
	check(victim.hp == 9976.0 and g.combat.traps.is_empty(), "Armed trap hits one victim and is consumed")
	for index in range(6): fire_component(g)
	check(g.combat.traps.size() == 3, "Trap capacity is bounded")
	g.combat.simulation_time = 9.0
	Traps.advance(g.combat)
	check(g.combat.traps.is_empty(), "Unused traps expire")
	for branch in ["dreadjaw", "scatterworks"]:
		g = setup("caltrop_keep", 4, branch)
		fire_component(g)
		check(g.combat.traps.size() == (3 if branch == "scatterworks" else 1), "Branch deployment count " + branch)
		g.economy.relocate("1", "0,0", 1)
		check(g.combat.traps.is_empty(), "Relocation removes owned traps " + branch)
	var campaign := Campaign.new(0, {}, "creative")
	campaign.game.data.balance = 100000.0
	var socket: int = campaign.mission.sockets[0].index
	campaign.build(socket, "caltrop_keep")
	var before: float = campaign.game.data.balance
	for index in range(50): campaign.tick(0.05)
	check(campaign.game.combat.traps.size() > 0 and campaign.game.combat.enemies.is_empty() and campaign.wave == 0 and campaign.game.data.balance == before, "Campaign planning prepares traps without enemies, waves, or income")

func composition() -> void:
	var component = Balance.Content.catalog().get_node("attribute/piercing_attack")
	for kind in ["rapid", "heavy"]:
		var g := setup(kind)
		var parent = Balance.Content.tower(kind)
		var assigned = parent.with_component("tower/" + kind + "/pierce-test", "attack", component, {"pierce_count": 2, "projectile_width": 12.0, "pierce_floor": 1.0})
		check(g.combat.set_tower_definition("1", assigned), "Attach reusable piercing to " + kind)
		var target := enemy(g, Vector2(60, Balance.PROJECTILES[kind].muzzle.y))
		var next := enemy(g, Vector2(90, Balance.PROJECTILES[kind].muzzle.y))
		fire_component(g, target)
		Lines.advance(g.combat, 1.0)
		check(target.hp < 10000 and next.hp < 10000, "Attached behavior reaches actual combat on " + kind)
		check(parent.rule("components", []).is_empty(), "Shared parent remains unchanged " + kind)
		fire_component(g, target)
		var removed = assigned.without_component("tower/" + kind + "/removed", "attack")
		g.combat.set_tower_definition("1", removed)
		check(g.combat.line_projectiles.is_empty() and g.combat.TowerComponents.attack_entry(g.combat, g.data.towers["1"], Balance.stats(kind, 1)).is_empty(), "Removing attachment cancels in-flight behavior " + kind)
	var a := setup("moonwheel")
	var b := setup("moonwheel")
	fire_component(a, enemy(a, Vector2(60, -32)))
	check(b.combat.line_projectiles.is_empty(), "Independent sessions share no live blade state")
