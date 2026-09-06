class_name VigilCombat
extends RefCounted

const Bosses = preload("res://scripts/model/bosses.gd")
const AttackEffects = preload("res://scripts/rendering/attack_effects.gd")

var data: Dictionary
var tuning: Dictionary:
	get: return data.settings.get("developer_balance", {})
var economy: VigilEconomy
var paths: Dictionary
var route_exits: Dictionary = {}
var branching_routes: Dictionary = {}
var enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var pending_shots: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var simulation_time := 0.0
var income_events: Array[Vector2] = []
var enemy_serial := 0
var tick_count := 0
var enemy_pool: Array[Dictionary] = []
var burning_ground: Array[Dictionary] = []
var curses: Dictionary = {}

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

func hit(enemy: Dictionary, damage: float, tower_id: String, branch: String = "", fire: bool = false) -> bool:
	if enemy.dead or not is_finite(damage) or damage <= 0.0 or not data.towers.has(tower_id):
		return false
	if enemy.get("boss", false):
		damage = Bosses.damage(enemy, damage, branch, fire)
	enemy.hp -= damage
	if enemy.hp > 0.0:
		return false
	# Mark dead synchronously before any credit, so splash and simultaneous shots are safe.
	enemy.dead = true
	var is_boss: bool = enemy.get("boss", false)
	var reward: float = Bosses.DEFINITIONS[enemy.kind].payout if is_boss else Balance.tuned_value("enemies", enemy.kind, "payout", tuning)
	if enemy.has("summoner"):
		reward = 0.0
	if is_boss:
		data.regions[enemy.source].boss = {"status": "defeated", "kind": enemy.kind}
	economy.credit(tower_id, reward)
	data.kills += 1.0
	var r: Dictionary = data.regions[enemy.source]
	# One-time encounters must not inflate recurring offline income.
	if not is_boss and not enemy.has("summoner"):
		r.history[tower_id] = r.history.get(tower_id, 0.0) + reward
	income_events.append(Vector2(simulation_time, reward))
	add_effect({"kind": "death", "pos": enemy.pos, "life": 0.45, "max_life": 0.45, "color": Bosses.DEFINITIONS[enemy.kind].color if is_boss else Balance.ENEMIES[enemy.kind].color})
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
	var s := Balance.definition("enemies", kind, tuning)
	enemy_serial += 1
	var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
	e.clear() # Pooled enemies must not inherit crowd control or charges.
	e.id = enemy_serial
	e.source = id
	e.kind = kind
	# Origin is captured once: crossing another biome never changes the effect.
	e.rift_style = r.get("style", "forest")
	e.hp = s.hp * rift_health_multiplier(e)
	e.max_hp = e.hp
	# Keep the chosen route on this enemy. A new purchase only changes future
	# spawns, never the path or segment index of an enemy already moving.
	# Linear routes share their cached array instead of copying it per spawn.
	e.path = VigilWorld.route(data.regions, id, route_exits, rng) if branching_routes[id] else paths[id]
	e.pos = e.path[0]
	e.segment = 1
	e.dead = false
	enemies.append(e)
	return e

func rift_health_multiplier(enemy: Dictionary) -> float:
	return 1.0 + Balance.rift_strength("ashen_forge", tuning) / 100.0 if enemy.get("rift_style", "forest") == "ashen_forge" else 1.0

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
	Bosses.advance(self, delta)
	for e in enemies:
		if e.dead:
			continue
		var move: float = (Bosses.speed(e, simulation_time) if e.get("boss", false) else Balance.tuned_value("enemies", e.kind, "speed", tuning)) * delta
		match e.get("rift_style", "forest"):
			"drowned_crypt":
				move *= 1.0 + Balance.rift_strength("drowned_crypt", tuning) / 100.0
			"bloodmoon_sanctuary":
				e.hp = minf(e.max_hp, e.hp + e.max_hp * Balance.rift_strength("bloodmoon_sanctuary", tuning) / 100.0 * delta)
		if e.get("slow_until", 0.0) > simulation_time:
			move *= 0.75
		if e.get("stun_until", 0.0) > simulation_time:
			move = 0.0
		var p: Array = e.path
		while move > 0.0 and not e.dead:
			var dist: float = e.pos.distance_to(p[e.segment])
			if move >= dist:
				e.pos = p[e.segment]
				e.segment += 1
				move -= dist
				if e.segment >= p.size():
					if e.get("boss", false) and e.tile != "0,0":
						Bosses.next_leg(self, e)
						p = e.path
						continue
					e.dead = true
					if e.get("boss", false):
						data.regions[e.source].boss = {"status": "escaped", "kind": e.kind}
					data.escapes += 1.0
					add_effect({"kind": "escape", "pos": e.pos, "life": 0.55, "max_life": 0.55, "color": "9bddd8"})
			else:
				e.pos = e.pos.move_toward(p[e.segment], move)
				move = 0.0
	# Resolve arrivals after movement, at the same center used by the visuals.
	advance_shots(delta)
	advance_fire(delta)
	# Spatial buckets keep targeting local as the battlefield grows.
	var buckets := {}
	for e in enemies:
		if not e.dead:
			# Compute road distance lazily for in-range candidates, once per tick.
			e.distance_remaining = -1.0
			var bucket := Vector2i(floor(e.pos.x / 128.0), floor(e.pos.y / 128.0))
			if not buckets.has(bucket):
				buckets[bucket] = []
			buckets[bucket].append(e)
	for t in data.towers.values():
		if t.get("rebuild_remaining", 0.0) > 0.0:
			t.rebuild_remaining = maxf(0.0, t.rebuild_remaining - delta)
			continue
		t.cooldown = maxf(0.0, t.cooldown - delta)
		# Decimal tier intervals can leave tiny positive floating-point residue.
		# Do not turn a 0.40-second attack into a 0.45-second attack.
		if t.cooldown > 0.000001:
			continue
		var stats := Balance.tower_stats(t, tuning)
		var pos := VigilWorld.pad_position(t.region, t.pad)
		var candidates := nearby(buckets, pos, stats.range)
		var target := select_target(candidates, pos, stats.range, t.get("target_mode", "first"))
		if target.is_empty():
			continue
		t.cooldown = stats.period
		t.angle = pos.angle_to_point(target.pos)
		if t.kind == "electric":
			# A new pulse replaces this tower's previous connections, even when
			# developer tuning makes attacks faster than the lightning fade.
			effects = effects.filter(func(fx): return not (fx.kind == "shot" and fx.get("tower_id", "") == t.id and fx.tower_kind == "electric"))
		if stats.get("targets", 1) > 1:
			# Pick distinct enemies in priority order before damage changes HP scores.
			var victims: Array[Dictionary] = [target]
			candidates.erase(target)
			for index in range(1, int(stats.targets)):
				var extra := select_target(candidates, pos, stats.range, t.get("target_mode", "first"))
				if extra.is_empty():
					break
				victims.append(extra)
				candidates.erase(extra)
			var used: Array = victims.map(func(e): return e.id)
			for victim in victims:
				launch_shot(t, pos, victim, stats)
				if t.get("branch", "") == "tempest_web":
					for other in enemies:
						if not other.dead and other.id not in used and victim.pos.distance_to(other.pos) <= 60.0:
							used.append(other.id)
							var arc := AttackEffects.shot("electric", victim.pos + Vector2(0, 29), other.pos, stats, other.id)
							arc.tower_id = t.id
							add_effect(arc)
							hit(other, stats.damage * 0.5, t.id)
							break
			continue
		launch_shot(t, pos, target, stats)
		if t.get("branch", "") == "thorn_volley":
			launch_fan(t, pos, target, stats)
	recycle_dead_enemies()
	while not income_events.is_empty() and simulation_time - income_events[0].x > 60.0:
		income_events.pop_front()
	if data.automation:
		economy.collect()

func launch_shot(tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	var fx := AttackEffects.shot(tower.kind, origin, target.pos, stats, target.id)
	fx.tower_id = tower.id
	fx.branch = tower.get("branch", "")
	add_effect(fx)
	var shot := {"fx": fx, "remaining": fx.flight, "target_id": target.id,
		"tower_id": tower.id, "branch": tower.get("branch", ""), "damage": stats.damage, "radius": 0.0 if stats.get("targets", 1) > 1 else stats.splash}
	if fx.flight <= 0.0:
		resolve_shot(shot, target)
	else:
		# Gameplay must not depend on whether the cosmetic effect pool is full.
		pending_shots.append(shot)

func advance_shots(delta: float) -> void:
	var targets := {}
	for enemy in enemies:
		targets[enemy.id] = enemy
	var flying: Array[Dictionary] = []
	var arrivals := pending_shots
	pending_shots = []
	for shot in arrivals:
		if shot.get("ballistic", false):
			advance_arrow(shot, delta, flying)
			continue
		var target: Dictionary = targets.get(shot.target_id, {})
		if not target.is_empty():
			shot.fx.pos = target.pos
		shot.remaining -= delta
		if shot.remaining <= 0.000001:
			resolve_shot(shot, target)
		else:
			flying.append(shot)
	pending_shots.append_array(flying)

func resolve_shot(shot: Dictionary, target: Dictionary) -> void:
	if shot.radius > 0.0:
		for enemy in enemies:
			if not enemy.dead and shot.fx.pos.distance_squared_to(enemy.pos) <= shot.radius * shot.radius:
				branch_hit(shot, enemy)
	elif not target.is_empty() and not target.dead:
		branch_hit(shot, target)
	if data.towers.has(shot.tower_id):
		if shot.get("branch", "") == "cinderfield":
			ignite(shot)
		elif shot.get("branch", "") == "grave_echo":
			launch_fragments(shot)
	# Traveling impacts stay at the arrival point instead of following survivors.
	if shot.fx.flight > 0.0:
		shot.fx.erase("target_id")

func distance_remaining(enemy: Dictionary) -> float:
	var path: Array = enemy.path
	var segment: int = enemy.segment
	var remaining: float = enemy.pos.distance_to(path[segment])
	for i in range(segment, path.size() - 1):
		remaining += path[i].distance_to(path[i + 1])
	return remaining

func select_target(candidates: Array, pos: Vector2, radius: float, mode: String) -> Dictionary:
	var target: Dictionary = {}
	var best_score := 0.0
	var best_distance := 0.0
	for enemy in candidates:
		if enemy.dead or pos.distance_squared_to(enemy.pos) > radius * radius:
			continue
		if enemy.distance_remaining < 0.0:
			enemy.distance_remaining = distance_remaining(enemy)
		var remaining: float = enemy.distance_remaining
		var score: float = enemy.hp if mode == "most_hp" else (remaining if mode == "last" else -remaining)
		# Equal HP prefers First; exact ties use spawn ID, never bucket order.
		if target.is_empty() or score > best_score or (score == best_score and (remaining < best_distance or (remaining == best_distance and enemy.id < target.id))):
			target = enemy
			best_score = score
			best_distance = remaining
	return target

func nearby(buckets: Dictionary, pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var first := Vector2i(floor((pos.x - radius) / 128.0), floor((pos.y - radius) / 128.0))
	var last := Vector2i(floor((pos.x + radius) / 128.0), floor((pos.y + radius) / 128.0))
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			result.append_array(buckets.get(Vector2i(x, y), []))
	return result

func recycle_dead_enemies() -> void:
	# Refresh after movement and attacks, before a dead dictionary can be reused.
	# Rendering uses these same enemy centers, so shots and impacts stay aligned.
	var targets := {}
	for e in enemies:
		targets[e.id] = e
	for fx in effects:
		if fx.kind != "shot" or not fx.has("target_id"):
			continue
		var target: Dictionary = targets.get(fx.target_id, {})
		if not target.is_empty():
			fx.pos = target.pos
		if target.is_empty() or target.dead:
			fx.erase("target_id")
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

# Branch state is transient: tower identity owns curses, enemy identity owns seals.
func branch_hit(shot: Dictionary, enemy: Dictionary) -> void:
	if not data.towers.has(shot.tower_id):
		return
	var branch: String = shot.get("branch", "")
	var damage: float = shot.damage
	if branch == "doomstone":
		var curse: Dictionary = curses.get(shot.tower_id, {"target": -1, "stacks": 0})
		curse.stacks = mini(5, int(curse.stacks) + 1) if curse.target == enemy.id else 0
		curse.target = enemy.id
		curses[shot.tower_id] = curse
		damage *= 1.0 + curse.stacks * 0.2
		enemy.curse_stacks = curse.stacks
	hit(enemy, damage, shot.tower_id, branch)
	if enemy.dead:
		return
	match branch:
		"frostneedle": enemy.slow_until = simulation_time + 2.0
		"rupture_pyre":
			if enemy.get("push_until", 0.0) <= simulation_time:
				push_back(enemy, 5.0 if enemy.kind == "heavy" else 20.0)
				enemy.push_until = simulation_time + 1.0
		"thunderseal":
			var charges: Dictionary = enemy.get("charges", {})
			charges[shot.tower_id] = int(charges.get(shot.tower_id, 0)) + 1
			if charges[shot.tower_id] >= 5:
				charges[shot.tower_id] = 0
				var bell: bool = enemy.get("boss", false) and enemy.kind == "bell"
				hit(enemy, damage * (4.5 if bell else 3.0), shot.tower_id, branch)
				if bell and not enemy.toll_delayed:
					enemy.toll += 2.0
					enemy.toll_delayed = true
				add_effect({"kind": "seal", "pos": enemy.pos, "life": 0.4, "max_life": 0.4, "color": "b3b5f1"})
				if enemy.get("stun_immune_until", 0.0) <= simulation_time:
					enemy.stun_until = simulation_time + 0.4
					enemy.stun_immune_until = simulation_time + 2.0
			enemy.charges = charges

func push_back(enemy: Dictionary, distance: float) -> void:
	while distance > 0.0:
		var previous: Vector2 = enemy.path[enemy.segment - 1]
		var step: float = enemy.pos.distance_to(previous)
		if step >= distance:
			enemy.pos = enemy.pos.move_toward(previous, distance)
			break
		enemy.pos = previous
		distance -= step
		if enemy.segment <= 1:
			break
		enemy.segment -= 1
	enemy.distance_remaining = -1.0

func ignite(shot: Dictionary) -> void:
	var patch := {"tower_id": shot.tower_id, "pos": shot.fx.pos, "radius": shot.radius, "until": simulation_time + 3.0, "damage": shot.damage / 0.75 / 3.0}
	for existing in burning_ground:
		if existing.tower_id == shot.tower_id and existing.pos.distance_to(patch.pos) <= existing.radius + patch.radius:
			existing.until = patch.until
			# Keep both footprints; per-enemy damage is deduplicated by owner.
			if existing.pos.distance_to(patch.pos) < 8.0:
				return
	burning_ground.append(patch)

func advance_fire(delta: float) -> void:
	for id in curses.keys():
		if not data.towers.has(id):
			curses.erase(id)
	if burning_ground.is_empty():
		return
	burning_ground = burning_ground.filter(func(p): return p.until > simulation_time and data.towers.has(p.tower_id))
	for enemy in enemies:
		if enemy.dead:
			continue
		var owners := {}
		for patch in burning_ground:
			if not owners.has(patch.tower_id) and enemy.pos.distance_squared_to(patch.pos) <= patch.radius * patch.radius:
				owners[patch.tower_id] = true
				hit(enemy, patch.damage * delta, patch.tower_id, "cinderfield", true)

func launch_fragments(shot: Dictionary) -> void:
	var count := 0
	for enemy in enemies:
		if enemy.dead or enemy.id == shot.target_id or enemy.pos.distance_to(shot.fx.pos) > 90.0:
			continue
		var stats := {"damage": shot.damage * 0.2, "splash": 0.0, "color": "c3a0ed"}
		var fx := AttackEffects.shot("heavy", shot.fx.pos + Vector2(0, 22), enemy.pos, stats, enemy.id)
		fx.fragment = true
		fx.curve = -1.0 if count % 2 == 0 else 1.0
		fx.tower_id = shot.tower_id
		add_effect(fx)
		pending_shots.append({"fx": fx, "remaining": fx.flight, "target_id": enemy.id, "tower_id": shot.tower_id, "damage": stats.damage, "radius": 0.0})
		count += 1
		if count == 5:
			break
	for index in range(count, 5):
		add_effect({"kind": "shard_fade", "pos": shot.fx.pos, "direction": Vector2.from_angle(index * TAU / 5.0), "life": 0.35, "max_life": 0.35, "color": "c3a0ed"})

func launch_fan(tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	var muzzle := origin + Vector2(0, -25)
	var angle := muzzle.angle_to_point(target.pos)
	for offset in [-0.48, -0.24, 0.24, 0.48]:
		var end: Vector2 = muzzle + Vector2.from_angle(angle + offset) * stats.range
		var fx := AttackEffects.shot("rapid", origin, end, stats)
		fx.erase("target_id")
		fx.flight = stats.range / 760.0
		fx.life = fx.flight + 0.09
		fx.max_life = fx.life
		fx.tower_id = tower.id
		add_effect(fx)
		pending_shots.append({"fx": fx, "remaining": fx.flight, "target_id": -1, "tower_id": tower.id, "damage": stats.damage, "radius": 0.0, "ballistic": true, "elapsed": 0.0})

func advance_arrow(shot: Dictionary, delta: float, flying: Array[Dictionary]) -> void:
	var start: Vector2 = shot.fx.from.lerp(shot.fx.pos, minf(1.0, shot.elapsed / shot.fx.flight))
	shot.elapsed += delta
	var end: Vector2 = shot.fx.from.lerp(shot.fx.pos, minf(1.0, shot.elapsed / shot.fx.flight))
	var victim: Dictionary = {}
	var nearest := INF
	for enemy in enemies:
		if enemy.dead:
			continue
		var point := Geometry2D.get_closest_point_to_segment(enemy.pos, start, end)
		if point.distance_to(enemy.pos) <= 9.0 and start.distance_to(point) < nearest:
			nearest = start.distance_to(point)
			victim = enemy
	if not victim.is_empty():
		hit(victim, shot.damage, shot.tower_id)
		shot.fx.life = 0.0
	elif shot.elapsed < shot.fx.flight:
		flying.append(shot)
