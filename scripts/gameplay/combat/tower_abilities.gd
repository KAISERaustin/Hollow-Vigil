extends RefCounted

# Capabilities are selected by immutable definitions; state belongs to recipients.
static func branch_hit(combat: VigilCombat, shot: Dictionary, enemy: Dictionary) -> void:
	if not combat.data.towers.has(shot.tower_id): return
	shot = shot.duplicate()
	combat.Relics.impact(combat, shot, enemy)
	combat.TowerComponents.before_hit(combat, shot, enemy)
	var tower: Dictionary = combat.data.towers[shot.tower_id]
	var capabilities: Array = shot.get("capabilities", [shot.get("branch", "")])
	var ability := Balance.tower_stats(tower, combat.tuning)
	var damage: float = shot.damage
	if "doomstone" in capabilities:
		var curse: Dictionary = combat.curses.get(shot.tower_id, {"target": -1, "stacks": 0})
		curse.stacks = mini(int(ability.curse_limit), int(curse.stacks) + 1) if curse.target == enemy.id else 0
		curse.target = enemy.id
		combat.curses[shot.tower_id] = curse
		damage *= 1.0 + curse.stacks * ability.curse_multiplier
		enemy.curse_stacks = curse.stacks
	var damage_type: String = shot.get("damage_type", Balance.Content.tower(shot.get("fx", {}).get("tower_kind", tower.kind)).rule("damage_type", "physical"))
	combat.hit(enemy, damage, shot.tower_id, shot.get("branch", ""), false, shot.get("relic_pierce", false), damage_type)
	combat.TowerComponents.after_hit(combat, shot, enemy)
	if enemy.dead: return
	for entry in shot.get("ability_effects", []):
		var node := Balance.Content.ability(entry.config.ability)
		if combat.StatComposition.has(tower, entry.config.ability, combat.tuning) and node != null and node.owns_effect(entry.config):
			entry.attribute.impact(combat, shot, enemy, entry.config)
	if "frostneedle" in capabilities:
		enemy.slow_until = combat.simulation_time + ability.slow_duration
		enemy.slow_percent = ability.slow_percent
		enemy.slow_owner = shot.tower_id
	if "rupture_pyre" in capabilities and enemy.get("push_until", 0.0) <= combat.simulation_time:
		combat.push_back(enemy, ability.push_distance * combat.EnemyCapabilities.resistance(enemy, "push_resistance", combat.tuning))
		enemy.push_until = combat.simulation_time + ability.push_immunity
	if "thunderseal" in capabilities:
		var charges: Dictionary = enemy.get("charges", {})
		charges[shot.tower_id] = int(charges.get(shot.tower_id, 0)) + 1
		if charges[shot.tower_id] >= ability.seal_hits:
			combat.sound_requested.emit("power_seal", enemy.pos)
			charges[shot.tower_id] = 0
			var summoner: bool = combat.EnemyCapabilities.has(enemy, "summon", combat.tuning)
			var stats := Balance.definition(combat.EnemyCapabilities.category(enemy), enemy.kind, combat.tuning)
			combat.hit(enemy, damage * (stats.seal_multiplier if summoner else ability.seal_damage), shot.tower_id, "thunderseal", false, false, "electric")
			if summoner and not enemy.get("toll_delayed", false):
				enemy.toll += stats.toll_delay
				enemy.toll_delayed = true
			combat.add_effect({"kind": "seal", "pos": enemy.pos, "life": 0.4, "max_life": 0.4, "color": "b3b5f1"})
			if enemy.get("stun_immune_until", 0.0) <= combat.simulation_time:
				enemy.stun_until = combat.simulation_time + ability.stun_duration
				enemy.stun_owner = shot.tower_id
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
