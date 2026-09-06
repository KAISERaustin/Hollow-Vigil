class_name VigilCombat
extends RefCounted

signal sound_requested(cue: String, position: Vector2)

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
var enemy_index := preload("res://scripts/model/enemy_index.gd").new()
var spatial_ready := false
var indexed_enemy_count := -1
var ticking := false

func rebuild_enemy_index() -> void:
	enemy_index.rebuild(enemies)
	indexed_enemy_count = enemies.size()
	spatial_ready = true

func nearby_enemies(pos: Vector2, radius: float) -> Array[Dictionary]:
	# Standalone combat helpers also support editor/test changes between calls.
	if not ticking:
		rebuild_enemy_index()
	return enemy_index.query_radius(pos, radius)

func visible_enemies(view: Rect2) -> Array[Dictionary]:
	if not spatial_ready or indexed_enemy_count != enemies.size():
		rebuild_enemy_index()
	return enemy_index.query_rect(view)

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
		var protection: float = enemy.get("shield", 0.0) + enemy.get("wards", 0)
		damage = Bosses.damage(enemy, damage, branch, fire, tuning)
		if protection > 0.0 and enemy.get("shield", 0.0) + enemy.get("wards", 0) <= 0.0:
			sound_requested.emit("boss_" + enemy.kind + "_break", enemy.pos)
	enemy.hp -= damage
	if enemy.hp > 0.0:
		return false
	# Mark dead synchronously before any credit, so splash and simultaneous shots are safe.
	enemy.dead = true
	sound_requested.emit("boss_" + enemy.kind + "_death" if enemy.get("boss", false) else "death_" + enemy.kind, enemy.pos)
	var is_boss: bool = enemy.get("boss", false)
	var reward: float = Balance.tuned_value("bosses", enemy.kind, "payout", tuning) if is_boss else Balance.tuned_value("enemies", enemy.kind, "payout", tuning)
	if enemy.has("summoner"):
		reward = 0.0
	if is_boss:
		Bosses.record(self, enemy.source).boss = {"status": "defeated", "kind": enemy.kind}
	economy.credit(tower_id, reward)
	data.kills += 1.0
	# One-time encounters must not inflate recurring offline income.
	if not is_boss and not enemy.has("summoner"):
		var r: Dictionary = data.regions[enemy.source]
		r.history[tower_id] = r.history.get(tower_id, 0.0) + reward
	income_events.append(Vector2(simulation_time, reward))
	add_effect({"kind": "death", "pos": enemy.pos, "life": 0.45, "max_life": 0.45, "color": Bosses.DEFINITIONS[enemy.kind].color if is_boss else Balance.ENEMIES[enemy.kind].color})
	return true

func add_effect(fx: Dictionary) -> void:
	if effects.size() < 100:
		effects.append(fx)

func spawn(id: String, forced_kind: String = "", escort: bool = false) -> Dictionary:
	if not VigilWorld.has_rift(id) or not data.regions.has(id):
		return {}
	var r: Dictionary = data.regions[id]
	var kind := forced_kind
	var dungeon: bool = r.get("style", "forest") == "castle_ruin"
	if kind == "":
		kind = Balance.DUNGEON_KINDS[rng.randi_range(0, 1)] if dungeon else Balance.enemy_kind(r.unlocks, rng.randf())
	if not escort and (kind in Balance.DUNGEON_KINDS) != dungeon:
		return {}
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
	spatial_ready = false
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
		var move: float = (Bosses.speed(e, simulation_time, tuning) if e.get("boss", false) else Balance.tuned_value("enemies", e.kind, "speed", tuning)) * delta
		match e.get("rift_style", "forest"):
			"drowned_crypt":
				move *= 1.0 + Balance.rift_strength("drowned_crypt", tuning) / 100.0
			"bloodmoon_sanctuary":
				e.hp = minf(e.max_hp, e.hp + e.max_hp * Balance.rift_strength("bloodmoon_sanctuary", tuning) / 100.0 * delta)
		if e.get("slow_until", 0.0) > simulation_time:
			move *= 1.0 - e.get("slow_percent", 25.0) / 100.0
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
					sound_requested.emit("boss_" + e.kind + "_escape" if e.get("boss", false) else "escape", e.pos)
					if e.get("boss", false):
						Bosses.record(self, e.source).boss = {"status": "escaped", "kind": e.kind}
					data.escapes += 1.0
					add_effect({"kind": "escape", "pos": e.pos, "life": 0.55, "max_life": 0.55, "color": "9bddd8"})
			else:
				e.pos = e.pos.move_toward(p[e.segment], move)
				move = 0.0
	# Build once after movement; knockback updates bucket membership immediately.
	rebuild_enemy_index()
	ticking = true
	for e in enemies:
		if not e.dead:
			e.distance_remaining = -1.0
	# Resolve arrivals at the same centers used by targeting and drawing.
	advance_shots(delta)
	advance_fire(delta)
	for t in data.towers.values():
		if t.get("rebuild_remaining", 0.0) > 0.0:
			t.rebuild_remaining = maxf(0.0, t.rebuild_remaining - delta)
			if t.rebuild_remaining <= 0.0:
				sound_requested.emit("menu_ready", VigilWorld.pad_position(t.region, t.pad))
			continue
		t.cooldown = maxf(0.0, t.cooldown - delta)
		# Decimal tier intervals can leave tiny positive floating-point residue.
		# Do not turn a 0.40-second attack into a 0.45-second attack.
		if t.cooldown > 0.000001:
			continue
		var stats := Balance.tower_stats(t, tuning)
		var pos := VigilWorld.pad_position(t.region, t.pad)
		var candidates := nearby_enemies(pos, stats.range)
		var target := select_target(candidates, pos, stats.range, t.get("target_mode", "first"))
		if target.is_empty():
			continue
		var voice: String = t.get("branch", "")
		if voice.is_empty():
			voice = t.kind
		sound_requested.emit("shot_" + voice, pos)
		t.cooldown = stats.period
		t.angle = pos.angle_to_point(target.pos)
		if t.kind == "electric":
			# A new pulse replaces this tower's previous connections, even when
			# developer tuning makes attacks faster than the lightning fade.
			effects = effects.filter(func(fx): return not (fx.kind == "shot" and fx.get("tower_id", "") == t.id and fx.tower_kind == "electric"))
		if stats.get("targets", 1) > 1 or t.get("branch", "") == "tempest_web":
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
					for other in nearby_enemies(victim.pos, stats.arc_range):
						if not other.dead and other.id not in used and victim.pos.distance_to(other.pos) <= stats.arc_range:
							used.append(other.id)
							var arc := AttackEffects.shot("electric", victim.pos + Vector2(0, 29), other.pos, stats, other.id)
							arc.tower_id = t.id
							add_effect(arc)
							hit(other, stats.damage * stats.arc_multiplier, t.id)
							break
			continue
		launch_shot(t, pos, target, stats)
	recycle_dead_enemies()
	indexed_enemy_count = enemies.size()
	ticking = false
	while not income_events.is_empty() and simulation_time - income_events[0].x > 60.0:
		income_events.pop_front()
	if data.automation:
		economy.collect()

func launch_shot(tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	if tower.get("branch", "") == "thorn_volley":
		launch_fan(tower, origin, target, stats)
	var fx := AttackEffects.shot(tower.kind, origin, target.pos, stats, target.id)
	fx.tower_id = tower.id
	fx.branch = tower.get("branch", "")
	add_effect(fx)
	var shot := {"fx": fx, "remaining": fx.flight, "target_id": target.id,
		"tower_id": tower.id, "branch": tower.get("branch", ""), "damage": stats.damage, "radius": stats.splash}
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
	if data.towers.has(shot.tower_id) and not shot.fx.get("fragment", false):
		var kind: String = shot.fx.get("tower_kind", data.towers[shot.tower_id].kind)
		var voice: String = shot.get("branch", "")
		if voice.is_empty():
			voice = kind
		# Use the launched projectile's voice even if its tower upgrades in flight.
		# Lightning's attack already is its impact. Avoid five simultaneous cues.
		if kind != "electric":
			sound_requested.emit("impact_" + voice, shot.fx.pos)
	if shot.radius > 0.0:
		for enemy in nearby_enemies(shot.fx.pos, shot.radius):
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
	if branch == "":
		hit(enemy, shot.damage, shot.tower_id)
		return
	var damage: float = shot.damage
	var ability: Dictionary = Balance.ABILITIES.get(branch, {}).duplicate()
	ability.merge(Balance.tower_stats(data.towers[shot.tower_id], tuning), true)
	if branch == "doomstone":
		var curse: Dictionary = curses.get(shot.tower_id, {"target": -1, "stacks": 0})
		curse.stacks = mini(int(ability.curse_limit), int(curse.stacks) + 1) if curse.target == enemy.id else 0
		curse.target = enemy.id
		curses[shot.tower_id] = curse
		damage *= 1.0 + curse.stacks * ability.curse_multiplier
		enemy.curse_stacks = curse.stacks
	hit(enemy, damage, shot.tower_id, branch)
	if enemy.dead:
		return
	match branch:
		"frostneedle":
			enemy.slow_until = simulation_time + ability.slow_duration
			enemy.slow_percent = ability.slow_percent
		"rupture_pyre":
			if enemy.get("push_until", 0.0) <= simulation_time:
				var resistance: float = Balance.tuned_value("bosses" if enemy.get("boss", false) else "enemies", enemy.kind, "push_resistance", tuning)
				push_back(enemy, ability.push_distance * (1.0 - resistance / 100.0))
				enemy.push_until = simulation_time + ability.push_immunity
		"thunderseal":
			var charges: Dictionary = enemy.get("charges", {})
			charges[shot.tower_id] = int(charges.get(shot.tower_id, 0)) + 1
			if charges[shot.tower_id] >= ability.seal_hits:
				sound_requested.emit("power_seal", enemy.pos)
				charges[shot.tower_id] = 0
				var bell: bool = enemy.get("boss", false) and enemy.kind == "bell"
				hit(enemy, damage * (Balance.tuned_value("bosses", "bell", "seal_multiplier", tuning) if bell else ability.seal_damage), shot.tower_id, branch)
				if bell and not enemy.toll_delayed:
					enemy.toll += Balance.tuned_value("bosses", "bell", "toll_delay", tuning)
					enemy.toll_delayed = true
				add_effect({"kind": "seal", "pos": enemy.pos, "life": 0.4, "max_life": 0.4, "color": "b3b5f1"})
				if enemy.get("stun_immune_until", 0.0) <= simulation_time:
					enemy.stun_until = simulation_time + ability.stun_duration
					enemy.stun_immune_until = simulation_time + ability.stun_immunity
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
	if spatial_ready:
		enemy_index.moved(enemy)

func ignite(shot: Dictionary) -> void:
	sound_requested.emit("power_ignite", shot.fx.pos)
	var ability := Balance.tower_stats(data.towers[shot.tower_id], tuning)
	var patch := {"tower_id": shot.tower_id, "pos": shot.fx.pos, "radius": shot.radius, "until": simulation_time + ability.get("burn_duration", 3.0), "damage": shot.damage * ability.get("burn_multiplier", 1.0 / 2.25)}
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
	# Keep patch order per enemy, including the first overlapping patch per owner.
	var affected := {}
	if not ticking:
		rebuild_enemy_index()
	for patch in burning_ground:
		for enemy in enemy_index.query_radius(patch.pos, patch.radius):
			if not affected.has(enemy.id):
				affected[enemy.id] = {"enemy": enemy, "patches": []}
			affected[enemy.id].patches.append(patch)
	var ids: Array = affected.keys()
	ids.sort_custom(func(a, b): return enemy_index.order[a] < enemy_index.order[b])
	for id in ids:
		var enemy: Dictionary = affected[id].enemy
		var owners := {}
		for patch in affected[id].patches:
			if not owners.has(patch.tower_id):
				owners[patch.tower_id] = true
				hit(enemy, patch.damage * delta, patch.tower_id, "cinderfield", true)

func launch_fragments(shot: Dictionary) -> void:
	sound_requested.emit("power_fragments", shot.fx.pos)
	var ability := Balance.tower_stats(data.towers[shot.tower_id], tuning)
	var limit := int(ability.get("fragment_count", 5))
	if limit == 0:
		return
	var count := 0
	for enemy in nearby_enemies(shot.fx.pos, ability.get("fragment_range", 90.0)):
		if enemy.dead or enemy.id == shot.target_id or enemy.pos.distance_to(shot.fx.pos) > ability.get("fragment_range", 90.0):
			continue
		var stats := {"damage": shot.damage * ability.get("fragment_multiplier", 0.2), "splash": 0.0, "color": "c3a0ed"}
		var fx := AttackEffects.shot("heavy", shot.fx.pos + Vector2(0, 22), enemy.pos, stats, enemy.id)
		fx.fragment = true
		fx.curve = -1.0 if count % 2 == 0 else 1.0
		fx.tower_id = shot.tower_id
		add_effect(fx)
		pending_shots.append({"fx": fx, "remaining": fx.flight, "target_id": enemy.id, "tower_id": shot.tower_id, "damage": stats.damage, "radius": 0.0})
		count += 1
		if count == limit:
			break
	for index in range(count, limit):
		add_effect({"kind": "shard_fade", "pos": shot.fx.pos, "direction": Vector2.from_angle(index * TAU / limit), "life": 0.35, "max_life": 0.35, "color": "c3a0ed"})

func launch_fan(tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	var muzzle := origin + Vector2(0, -25)
	var angle := muzzle.angle_to_point(target.pos)
	var count := int(stats.get("arrow_count", 5))
	for index in range(count - 1):
		var slot := index if index < count / 2 else index + 1
		var fraction := float(slot) / maxf(1.0, count - 1)
		var offset: float = (fraction - 0.5) * stats.get("fan_angle", 0.96)
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
	if not ticking:
		rebuild_enemy_index()
	for enemy in enemy_index.query_rect(Rect2(start, Vector2.ZERO).expand(end).grow(9.0)):
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
