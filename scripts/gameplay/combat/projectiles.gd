extends RefCounted

const ShotFactory = preload("res://scripts/gameplay/combat/shot_factory.gd")

# Stateless operations; VigilCombat owns the runtime data and simulation clock.

static func launch_shot(combat: VigilCombat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary, primary: bool = true) -> void:
	var fx := ShotFactory.shot(tower.kind, origin, target.pos, stats, target.id)
	fx.tower_id = tower.id
	fx.branch = tower.get("branch", "")
	combat.add_effect(fx)
	var shot := {"fx": fx, "remaining": fx.flight, "target_id": target.id,
		"tower_id": tower.id, "branch": tower.get("branch", ""), "damage": stats.damage, "radius": stats.splash}
	shot.base_damage = stats.damage
	var ability := Balance.Content.ability(shot.branch)
	shot.ability_effects = ability.impact_effects(stats) if primary and ability != null else []
	shot.relic_pierce = primary and stats.get("relic_pierce", false)
	if primary:
		shot.damage *= stats.get("relic_damage_multiplier", 1.0)
		shot.radius = maxf(shot.radius, stats.get("relic_radius", 0.0))
		shot.gear_effects = stats.get("gear_effects", []).duplicate(true)
		shot.gear_epoch = stats.get("gear_epoch", -1)
		if shot.damage != stats.damage or shot.relic_pierce or not shot.gear_effects.is_empty():
			fx.color = stats.get("gear_color", stats.color)
	for echo in stats.get("gear_echoes", []) if primary else []:
		# A single extra primary projectile, with no recursive branch/relic procs.
		var echo_stats := stats.duplicate()
		echo_stats.color = stats.get("gear_color", stats.color)
		var echo_fx := ShotFactory.shot(tower.kind, origin, target.pos, echo_stats, target.id)
		echo_fx.tower_id = tower.id
		echo_fx.flight += echo.delay
		echo_fx.life += echo.delay
		echo_fx.max_life = echo_fx.life
		combat.add_effect(echo_fx)
		combat.pending_shots.append({"fx": echo_fx, "remaining": echo_fx.flight, "target_id": target.id, "tower_id": tower.id, "damage": stats.damage * echo.multiplier, "radius": stats.splash})
	for fork in stats.get("gear_forks", []) if primary else []:
		var remaining: int = int(fork.fork_count)
		for enemy in combat.nearby_enemies(target.pos, fork.fork_radius):
			if remaining <= 0:
				break
			if enemy.dead or enemy.id == target.id or target.pos.distance_to(enemy.pos) > fork.fork_radius:
				continue
			var fork_stats := stats.duplicate()
			fork_stats.color = stats.get("gear_color", stats.color)
			var fork_fx := ShotFactory.shot(tower.kind, origin, enemy.pos, fork_stats, enemy.id)
			fork_fx.tower_id = tower.id
			combat.add_effect(fork_fx)
			combat.pending_shots.append({"fx": fork_fx, "remaining": fork_fx.flight, "target_id": enemy.id, "tower_id": tower.id, "damage": stats.damage * fork.fork_multiplier, "radius": 0.0})
			remaining -= 1
	if fx.flight <= 0.0:
		combat.resolve_shot(shot, target)
	else:
		# Gameplay must not depend on whether the cosmetic effect pool is full.
		combat.pending_shots.append(shot)

static func advance_shots(combat: VigilCombat, delta: float) -> void:
	var targets := {}
	for enemy in combat.enemies:
		targets[enemy.id] = enemy
	var flying: Array[Dictionary] = []
	var arrivals := combat.pending_shots
	combat.pending_shots = []
	for shot in arrivals:
		if shot.get("ballistic", false):
			combat.advance_arrow(shot, delta, flying)
			continue
		var target: Dictionary = targets.get(shot.target_id, {})
		if not target.is_empty():
			shot.fx.pos = target.pos
		shot.remaining -= delta
		if shot.remaining <= 0.000001:
			combat.resolve_shot(shot, target)
		else:
			flying.append(shot)
	combat.pending_shots.append_array(flying)

static func resolve_shot(combat: VigilCombat, shot: Dictionary, target: Dictionary) -> void:
	combat.Relics.arrive(combat, shot)
	if combat.data.towers.has(shot.tower_id) and not shot.fx.get("fragment", false):
		var kind: String = shot.fx.get("tower_kind", combat.data.towers[shot.tower_id].kind)
		var voice: String = shot.get("branch", "")
		if voice.is_empty():
			voice = kind
		# Use the launched projectile's voice even if its tower upgrades in flight.
		# Lightning's attack already is its impact. Avoid five simultaneous cues.
		if kind != "electric":
			combat.sound_requested.emit("impact_" + voice, shot.fx.pos)
	if shot.radius > 0.0:
		for enemy in combat.nearby_enemies(shot.fx.pos, shot.radius):
			if not enemy.dead and shot.fx.pos.distance_squared_to(enemy.pos) <= shot.radius * shot.radius:
				combat.branch_hit(shot, enemy)
	elif not target.is_empty() and not target.dead:
		combat.branch_hit(shot, target)
	if combat.data.towers.has(shot.tower_id):
		if shot.get("branch", "") == "cinderfield":
			combat.ignite(shot)
		elif shot.get("branch", "") == "grave_echo":
			combat.launch_fragments(shot)
	# Traveling impacts stay at the arrival point instead of following survivors.
	if shot.fx.flight > 0.0:
		shot.fx.erase("target_id")

static func launch_fragments(combat: VigilCombat, shot: Dictionary) -> void:
	combat.sound_requested.emit("power_fragments", shot.fx.pos)
	var ability := Balance.tower_stats(combat.data.towers[shot.tower_id], combat.tuning)
	var limit := int(ability.fragment_count)
	if limit == 0:
		return
	var count := 0
	for enemy in combat.nearby_enemies(shot.fx.pos, ability.fragment_range):
		if enemy.dead or enemy.id == shot.target_id or enemy.pos.distance_to(shot.fx.pos) > ability.fragment_range:
			continue
		var stats := {"damage": shot.damage * ability.fragment_multiplier, "splash": 0.0, "color": "c3a0ed"}
		var fx := ShotFactory.shot("heavy", shot.fx.pos - Balance.PROJECTILES.heavy.muzzle, enemy.pos, stats, enemy.id)
		fx.fragment = true
		fx.curve = -1.0 if count % 2 == 0 else 1.0
		fx.tower_id = shot.tower_id
		combat.add_effect(fx)
		combat.pending_shots.append({"fx": fx, "remaining": fx.flight, "target_id": enemy.id, "tower_id": shot.tower_id, "damage": stats.damage, "radius": 0.0})
		count += 1
		if count == limit:
			break
	for index in range(count, limit):
		combat.add_effect({"kind": "shard_fade", "pos": shot.fx.pos, "direction": Vector2.from_angle(index * TAU / limit), "life": 0.35, "max_life": 0.35, "color": "c3a0ed"})

static func advance_arrow(combat: VigilCombat, shot: Dictionary, delta: float, flying: Array[Dictionary]) -> void:
	var start: Vector2 = shot.fx.from.lerp(shot.fx.pos, minf(1.0, shot.elapsed / shot.fx.flight))
	shot.elapsed += delta
	var end: Vector2 = shot.fx.from.lerp(shot.fx.pos, minf(1.0, shot.elapsed / shot.fx.flight))
	var victim: Dictionary = {}
	var nearest := INF
	if not combat.ticking:
		combat.rebuild_enemy_index()
	for enemy in combat.enemy_index.query_rect(Rect2(start, Vector2.ZERO).expand(end).grow(9.0)):
		if enemy.dead:
			continue
		var point := Geometry2D.get_closest_point_to_segment(enemy.pos, start, end)
		if point.distance_to(enemy.pos) <= 9.0 and start.distance_to(point) < nearest:
			nearest = start.distance_to(point)
			victim = enemy
	if not victim.is_empty():
		combat.hit(victim, shot.damage, shot.tower_id)
		shot.fx.life = 0.0
	elif shot.elapsed < shot.fx.flight:
		flying.append(shot)
