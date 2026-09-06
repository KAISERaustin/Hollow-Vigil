extends RefCounted

# Stateless operations; VigilCombat owns the runtime data and simulation clock.

static func branch_hit(combat: VigilCombat, shot: Dictionary, enemy: Dictionary) -> void:
	if not combat.data.towers.has(shot.tower_id):
		return
	combat.Relics.root_target(combat, shot, enemy)
	var pierce: bool = shot.get("relic_pierce", false)
	var branch: String = shot.get("branch", "")
	if branch == "":
		combat.hit(enemy, shot.damage, shot.tower_id, "", false, pierce)
		return
	var damage: float = shot.damage
	# The launched branch can differ from the owner's current form (including
	# scripted attacks). Its defaults still come from the shared catalog.
	var ability: Dictionary = Balance.ABILITIES.get(branch, {}).duplicate()
	ability.merge(Balance.tower_stats(combat.data.towers[shot.tower_id], combat.tuning), true)
	if branch == "doomstone":
		var curse: Dictionary = combat.curses.get(shot.tower_id, {"target": -1, "stacks": 0})
		curse.stacks = mini(int(ability.curse_limit), int(curse.stacks) + 1) if curse.target == enemy.id else 0
		curse.target = enemy.id
		combat.curses[shot.tower_id] = curse
		damage *= 1.0 + curse.stacks * ability.curse_multiplier
		enemy.curse_stacks = curse.stacks
	combat.hit(enemy, damage, shot.tower_id, branch, false, pierce)
	if enemy.dead:
		return
	match branch:
		"frostneedle":
			enemy.slow_until = combat.simulation_time + ability.slow_duration
			enemy.slow_percent = ability.slow_percent
		"rupture_pyre":
			if enemy.get("push_until", 0.0) <= combat.simulation_time:
				var resistance: float = Balance.tuned_value("bosses" if enemy.get("boss", false) else "enemies", enemy.kind, "push_resistance", combat.tuning)
				combat.push_back(enemy, ability.push_distance * (1.0 - resistance / 100.0))
				enemy.push_until = combat.simulation_time + ability.push_immunity
		"thunderseal":
			var charges: Dictionary = enemy.get("charges", {})
			charges[shot.tower_id] = int(charges.get(shot.tower_id, 0)) + 1
			if charges[shot.tower_id] >= ability.seal_hits:
				combat.sound_requested.emit("power_seal", enemy.pos)
				charges[shot.tower_id] = 0
				var bell: bool = enemy.get("boss", false) and enemy.kind == "bell"
				combat.hit(enemy, damage * (Balance.tuned_value("bosses", "bell", "seal_multiplier", combat.tuning) if bell else ability.seal_damage), shot.tower_id, branch)
				if bell and not enemy.toll_delayed:
					enemy.toll += Balance.tuned_value("bosses", "bell", "toll_delay", combat.tuning)
					enemy.toll_delayed = true
				combat.add_effect({"kind": "seal", "pos": enemy.pos, "life": 0.4, "max_life": 0.4, "color": "b3b5f1"})
				if enemy.get("stun_immune_until", 0.0) <= combat.simulation_time:
					enemy.stun_until = combat.simulation_time + ability.stun_duration
					enemy.stun_immune_until = combat.simulation_time + ability.stun_immunity
			enemy.charges = charges

static func push_back(combat: VigilCombat, enemy: Dictionary, distance: float) -> void:
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
	if combat.spatial_ready:
		combat.enemy_index.moved(enemy)

static func ignite(combat: VigilCombat, shot: Dictionary) -> void:
	combat.sound_requested.emit("power_ignite", shot.fx.pos)
	var ability := Balance.tower_stats(combat.data.towers[shot.tower_id], combat.tuning)
	var patch := {"tower_id": shot.tower_id, "pos": shot.fx.pos, "radius": shot.radius, "until": combat.simulation_time + ability.burn_duration, "damage": shot.damage * ability.burn_multiplier}
	for existing in combat.burning_ground:
		if existing.tower_id == shot.tower_id and existing.pos.distance_to(patch.pos) <= existing.radius + patch.radius:
			existing.until = patch.until
			# Keep both footprints; per-enemy damage is deduplicated by owner.
			if existing.pos.distance_to(patch.pos) < 8.0:
				return
	combat.burning_ground.append(patch)

static func advance_fire(combat: VigilCombat, delta: float) -> void:
	for id in combat.curses.keys():
		if not combat.data.towers.has(id):
			combat.curses.erase(id)
	if combat.burning_ground.is_empty():
		return
	combat.burning_ground = combat.burning_ground.filter(func(p): return p.until > combat.simulation_time and combat.data.towers.has(p.tower_id))
	# Keep patch order per enemy, including the first overlapping patch per owner.
	var affected := {}
	if not combat.ticking:
		combat.rebuild_enemy_index()
	for patch in combat.burning_ground:
		for enemy in combat.enemy_index.query_radius(patch.pos, patch.radius):
			if not affected.has(enemy.id):
				affected[enemy.id] = {"enemy": enemy, "patches": []}
			affected[enemy.id].patches.append(patch)
	var ids: Array = affected.keys()
	ids.sort_custom(func(a, b): return combat.enemy_index.order[a] < combat.enemy_index.order[b])
	for id in ids:
		var enemy: Dictionary = affected[id].enemy
		var owners := {}
		for patch in affected[id].patches:
			if not owners.has(patch.tower_id):
				owners[patch.tower_id] = true
				combat.hit(enemy, patch.damage * delta, patch.tower_id, "cinderfield", true)
