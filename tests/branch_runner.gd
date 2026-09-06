extends SceneTree

var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func fixture(kind: String, branch: String) -> VigilState:
	var g := VigilState.new(123)
	g.data.balance = 10000.0
	g.expand("-1,0")
	g.data.regions["-1,0"].style = "forest" # Measure tower branches without biome effects.
	g.data.regions["-1,0"].timer = 10.0
	var id := g.economy.build(kind,"0,0",0)
	g.economy.upgrade(id)
	g.economy.upgrade(id)
	if branch != "":
		g.economy.upgrade(id,3,branch)
	return g
func enemy(g: VigilState, pos := Vector2.ZERO, kind := "basic") -> Dictionary:
	var e := g.combat.spawn("-1,0",kind)
	e.hp = 10000.0
	e.max_hp = e.hp
	e.pos = pos
	e.path = [pos-Vector2(100,0),pos+Vector2(10000,0)]
	e.segment = 1
	e.distance_remaining = -1.0
	return e
func shot(g: VigilState, e: Dictionary) -> Dictionary:
	var t: Dictionary = g.data.towers["1"]
	var stats := Balance.tower_stats(t)
	return {"tower_id":"1","target_id":e.id,"branch":t.branch,"damage":stats.damage,"radius":stats.splash,"fx":{"pos":e.pos,"flight":0.2}}
func run() -> void:
	for kind in Balance.BRANCHES:
		for branch in Balance.BRANCHES[kind]:
			var g := fixture(kind,"")
			var before := g.data.duplicate(true)
			check(not g.economy.upgrade("1",3) and g.data == before,"Branch required: "+kind)
			check(not g.economy.upgrade("1",3,"invalid") and g.data == before,"Invalid branch rejected")
			g.data.balance = Balance.upgrade_cost(g.data.towers["1"])-1
			check(not g.economy.upgrade("1",3,branch),"Insufficient branch funds rejected")
			g.data.balance += 1
			check(g.economy.upgrade("1",3,branch) and g.data.balance == 0,"Exact branch price accepted")
			check(g.data.towers["1"].branch == branch and g.data.towers["1"].level == 4,"Branch identity committed")
			check(g.storage.valid_data(g.data),"Branch save valid")
			g.save_path = "user://branch-test.save"
			check(g.save(1000),"Branch saved")
			var read := g.storage.read_candidate(g.save_path)
			check(read.towers["1"].branch == branch,"Branch roundtrip")
			check(not g.economy.upgrade("1",4,branch) and Balance.upgrade_cost(g.data.towers["1"]) == 0,"Level four cap")
			var malformed := g.data.duplicate(true)
			malformed.towers["1"].branch = "invalid"
			check(not g.storage.valid_data(malformed),"Invalid saved branch rejected")
			g.data.balance = 10000
			check(g.economy.relocate("1","0,0",1,4) and g.data.towers["1"].branch == branch,"Moving preserves branch")
			check(g.economy.sell("1",4).refund == Balance.sell_refund(read.towers["1"]),"Sale includes branch cost")
			for suffix in ["", ".tmp", ".bak"]:
				DirAccess.remove_absolute(g.save_path+suffix)
	var g := fixture("rapid","frostneedle")
	var e := enemy(g)
	g.combat.branch_hit(shot(g,e),e)
	check(e.slow_until == 2.0,"Frost slow lasts two seconds")
	g.data.towers["1"].cooldown = 10
	g.combat.tick(0.5)
	check(is_equal_approx(e.pos.x,39*0.5*0.75),"Slow reduces movement exactly 25 percent")
	g.combat.branch_hit(shot(g,e),e)
	check(e.slow_until == 2.5,"Slow refreshes instead of stacking")
	g = fixture("splash","rupture_pyre")
	e = enemy(g)
	var heavy := enemy(g,Vector2.ZERO,"heavy")
	g.combat.branch_hit(shot(g,e),e)
	g.combat.branch_hit(shot(g,heavy),heavy)
	check(e.pos.x == -20 and heavy.pos.x == -5,"Heavy enemy resists push")
	g.combat.branch_hit(shot(g,e),e)
	check(e.pos.x == -20,"Push immunity prevents repeat trapping")
	e.path = [Vector2(-10,0),Vector2.ZERO,Vector2(100,0)]
	e.segment = 2
	e.pos = Vector2(5,0)
	g.combat.push_back(e,12)
	check(e.pos == Vector2(-7,0) and e.segment == 1,"Push crosses path segments safely")
	g = fixture("splash","cinderfield")
	e = enemy(g)
	var fire := shot(g,e)
	g.combat.ignite(fire)
	g.combat.ignite(fire)
	g.combat.advance_fire(1)
	check(e.hp == 9988 and g.combat.burning_ground.size() == 1,"Same-tower fire does not stack")
	g.combat.simulation_time = 3.1
	g.combat.advance_fire(1)
	check(e.hp == 9988 and g.combat.burning_ground.is_empty(),"Fire expires")
	g = fixture("heavy","grave_echo")
	e = enemy(g)
	for index in range(7):
		enemy(g,Vector2(10+index*5,0))
	g.combat.resolve_shot(shot(g,e),e)
	check(g.combat.pending_shots.size() == 5,"Exactly five seeking fragments")
	var ids := {}
	for fragment in g.combat.pending_shots:
		ids[fragment.target_id] = true
		check(fragment.target_id != e.id and is_equal_approx(fragment.damage,22),"Fragment excludes original and deals twenty percent")
	check(ids.size() == 5,"Fragments choose distinct enemies")
	g.combat.advance_shots(1)
	check(g.combat.pending_shots.is_empty() and is_equal_approx(e.hp,9890),"Fragments land without recursive splitting")
	g = fixture("heavy","doomstone")
	e = enemy(g)
	for index in range(7):
		g.combat.branch_hit(shot(g,e),e)
	check(g.combat.curses["1"].stacks == 5 and e.hp == 9010,"Curse reaches and respects damage cap")
	var other := enemy(g)
	g.combat.branch_hit(shot(g,other),other)
	check(other.hp == 9910 and g.combat.curses["1"].stacks == 0,"Switching target resets curse")
	g = fixture("electric","thunderseal")
	e = enemy(g)
	for index in range(5):
		g.combat.branch_hit(shot(g,e),e)
	check(e.hp == 9944 and e.charges["1"] == 0 and e.stun_until == 0.4,"Fifth seal hit detonates and resets")
	g.combat.simulation_time = 1
	for index in range(5):
		g.combat.branch_hit(shot(g,e),e)
	check(e.stun_until == 0.4,"Stun immunity prevents repeated lockdown")
	g = fixture("electric","tempest_web")
	var origin := VigilWorld.pad_position("0,0",0)
	for index in range(10):
		enemy(g,origin+Vector2(140+index*5,0))
	g.combat.tick(0.05)
	var damaged := 0
	for victim in g.combat.enemies:
		if victim.hp < 10000: damaged += 1
	check(damaged == 10,"Five primary strikes arc to five distinct enemies beyond tower range")
	g = fixture("rapid","thorn_volley")
	origin = VigilWorld.pad_position("0,0",0)
	e = enemy(g,origin+Vector2(100,-25))
	g.combat.launch_fan(g.data.towers["1"],origin,e,Balance.tower_stats(g.data.towers["1"]))
	check(g.combat.pending_shots.size() == 4,"Fan has four ballistic outer arrows")
	other = enemy(g,origin+Vector2(0,-25)+Vector2.from_angle(0.24)*70)
	g.combat.advance_shots(1)
	check(e.hp == 10000 and other.hp == 9985,"Outer arrows miss center and hit off-axis enemy")
	print("BRANCH RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
