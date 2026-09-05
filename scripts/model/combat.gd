class_name VigilCombat
extends RefCounted

const AttackEffects = preload("res://scripts/rendering/attack_effects.gd")

var data: Dictionary
var economy: VigilEconomy
var paths: Dictionary
var route_exits: Dictionary = {}
var branching_routes: Dictionary = {}
var enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var simulation_time := 0.0
var income_events: Array[Vector2] = []
var enemy_serial := 0
var tick_count := 0
var enemy_pool: Array[Dictionary] = []

func _init(shared_data: Dictionary, transactions: VigilEconomy, shared_paths: Dictionary) -> void:
	data = shared_data
	economy = transactions
	paths = shared_paths
	rng.randomize()

func rebuild_routes() -> void:
	route_exits = VigilWorld.shortest_exits(data.regions)
	paths.clear()
	branching_routes.clear()
	for id in route_exits:
		paths[id] = VigilWorld.route(data.regions, id, route_exits)
		var choices: Array = route_exits[id]
		branching_routes[id] = choices.size() > 1 or (not choices.is_empty() and branching_routes[choices[0]])

func hit(enemy: Dictionary, damage: float, tower_id: String) -> bool:
	if enemy.dead or not is_finite(damage) or damage <= 0.0 or not data.towers.has(tower_id):
		return false
	enemy.hp -= damage
	if enemy.hp > 0.0:
		return false
	# Mark dead synchronously before any credit, so splash and simultaneous shots are safe.
	enemy.dead = true
	var reward: float = Balance.ENEMIES[enemy.kind].payout
	economy.credit(tower_id, reward)
	data.kills += 1.0
	var r: Dictionary = data.regions[enemy.source]
	r.history[tower_id] = r.history.get(tower_id, 0.0) + reward
	income_events.append(Vector2(simulation_time, reward))
	add_effect({"kind": "death", "pos": enemy.pos, "life": 0.45, "max_life": 0.45, "color": Balance.ENEMIES[enemy.kind].color})
	return true

func add_effect(fx: Dictionary) -> void:
	if effects.size() < 100:
		effects.append(fx)

func spawn(id: String, forced_kind: String = "") -> Dictionary:
	if not VigilWorld.has_rift(id) or not data.regions.has(id):
		return {}
	var r: Dictionary = data.regions[id]
	var kind := forced_kind
	if kind == "":
		kind = Balance.enemy_kind(r.unlocks, rng.randf())
	if not Balance.ENEMIES.has(kind):
		return {}
	var s: Dictionary = Balance.ENEMIES[kind]
	enemy_serial += 1
	var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
	e.id = enemy_serial
	e.source = id
	e.kind = kind
	e.hp = s.hp
	e.max_hp = s.hp
	# Keep the chosen route on this enemy. A new purchase only changes future
	# spawns, never the path or segment index of an enemy already moving.
	# Linear routes share their cached array instead of copying it per spawn.
	e.path = VigilWorld.route(data.regions, id, route_exits, rng) if branching_routes[id] else paths[id]
	e.pos = e.path[0]
	e.segment = 1
	e.dead = false
	enemies.append(e)
	return e

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	# Age existing effects first so a fresh projectile starts at its muzzle.
	for fx in effects:
		fx.life -= delta
	effects = effects.filter(func(fx): return fx.life > 0.0)
	simulation_time += delta
	data.active_seconds += delta
	tick_count += 1
	# Every rift advances on the same clock. Camera visibility only affects drawing.
	for r in data.regions.values():
		if not VigilWorld.has_rift(r.id):
			continue
		r.history_time = minf(Balance.HISTORY_SECONDS, r.history_time + delta)
		# Offline estimates include time with escapes / no kills across the whole world.
		if r.history_time >= Balance.HISTORY_SECONDS:
			for tid in r.history:
				r.history[tid] *= exp(-delta / Balance.HISTORY_SECONDS)
		r.timer -= delta
		while r.timer <= 0.0:
			spawn(r.id)
			r.timer += economy.spawn_period(r.id) * rng.randf_range(0.9, 1.1)
	for e in enemies:
		if e.dead:
			continue
		var move: float = Balance.ENEMIES[e.kind].speed * delta
		var p: Array = e.path
		while move > 0.0 and not e.dead:
			var dist: float = e.pos.distance_to(p[e.segment])
			if move >= dist:
				e.pos = p[e.segment]
				e.segment += 1
				move -= dist
				if e.segment >= p.size():
					e.dead = true
					data.escapes += 1.0
					add_effect({"kind": "escape", "pos": e.pos, "life": 0.55, "max_life": 0.55, "color": "9bddd8"})
			else:
				e.pos = e.pos.move_toward(p[e.segment], move)
				move = 0.0
	# Spatial buckets keep targeting local as the battlefield grows.
	var buckets := {}
	for e in enemies:
		if not e.dead:
			var bucket := Vector2i(floor(e.pos.x / 128.0), floor(e.pos.y / 128.0))
			if not buckets.has(bucket):
				buckets[bucket] = []
			buckets[bucket].append(e)
	for t in data.towers.values():
		t.cooldown = maxf(0.0, t.cooldown - delta)
		if t.cooldown > 0.0:
			continue
		var stats := Balance.stats(t.kind, t.level)
		var pos := VigilWorld.pad_position(t.region, t.pad)
		var candidates := nearby(buckets, pos, stats.range)
		var target: Dictionary = {}
		# Consistent oldest-in-range policy, independent of render frame rate.
		for e in candidates:
			if not e.dead and pos.distance_squared_to(e.pos) <= stats.range * stats.range:
				if target.is_empty() or e.id < target.id:
					target = e
		if target.is_empty():
			continue
		t.cooldown = stats.period
		t.angle = pos.angle_to_point(target.pos)
		var impact: Vector2 = target.pos
		if stats.splash > 0.0:
			for e in nearby(buckets, impact, stats.splash):
				if not e.dead and impact.distance_squared_to(e.pos) <= stats.splash * stats.splash:
					hit(e, stats.damage, t.id)
		else:
			hit(target, stats.damage, t.id)
		add_effect(AttackEffects.shot(t.kind, pos, impact, stats))
	recycle_dead_enemies()
	while not income_events.is_empty() and simulation_time - income_events[0].x > 60.0:
		income_events.pop_front()
	if data.automation:
		economy.collect()

func nearby(buckets: Dictionary, pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var first := Vector2i(floor((pos.x - radius) / 128.0), floor((pos.y - radius) / 128.0))
	var last := Vector2i(floor((pos.x + radius) / 128.0), floor((pos.y + radius) / 128.0))
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			result.append_array(buckets.get(Vector2i(x, y), []))
	return result

func recycle_dead_enemies() -> void:
	var live: Array[Dictionary] = []
	for e in enemies:
		if not e.dead:
			live.append(e)
		elif enemy_pool.size() < 128:
			enemy_pool.append(e)
	enemies = live

func income_rate() -> float:
	# Gold per second, averaged over up to 60 seconds with a 10-second startup floor.
	var amount := 0.0
	for event in income_events:
		amount += event.y
	return amount / maxf(10.0, minf(60.0, simulation_time))
