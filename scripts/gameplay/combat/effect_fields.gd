extends RefCounted

## Ground effects live in the combat owner, with immutable launch parameters.
static func add(combat: VigilCombat, shot: Dictionary, component: RefCounted, config: Dictionary) -> void:
	if config.duration <= 0.0 or config.area_radius <= 0.0 or config.dot_multiplier <= 0.0:
		return
	var field := {"tower_id": shot.tower_id, "component": component, "config": config.duplicate(true),
		"epoch": shot.gear_epoch, "pos": shot.fx.pos, "radius": config.area_radius,
		"from": combat.simulation_time, "until": combat.simulation_time + config.duration,
		"damage": shot.base_damage * config.dot_multiplier, "fire": config.get("fire_damage", 0.0) > 0.0}
	# Exact repeats can refresh one footprint; distinct centers keep their area.
	for previous in combat.effect_fields:
		if previous.tower_id == field.tower_id and previous.component == component and previous.pos.is_equal_approx(field.pos):
			previous.merge(field, true)
			return
	combat.effect_fields.append(field)

static func clear(combat: VigilCombat, tower_id: String) -> void:
	combat.effect_fields = combat.effect_fields.filter(func(field): return field.tower_id != tower_id)

static func advance(combat: VigilCombat, delta: float) -> void:
	var survivors: Array[Dictionary] = []
	var affected := {}
	for field in combat.effect_fields:
		if not combat.data.towers.has(field.tower_id) or field.epoch != combat.relic_epochs.get(field.tower_id, 0):
			continue
		var gear := Balance.Content.gear(combat.Relics.kind(combat.data, combat.data.towers[field.tower_id]))
		if gear == null or not gear.owns_effect(field.config):
			continue
		var elapsed := maxf(0.0, minf(field.until, combat.simulation_time) - maxf(field.from, combat.simulation_time - delta))
		if field.until > combat.simulation_time:
			survivors.append(field)
		if elapsed <= 0.0:
			continue
		for enemy in combat.nearby_enemies(field.pos, field.radius):
			if enemy.dead or enemy.pos.distance_squared_to(field.pos) > field.radius * field.radius:
				continue
			var key: String = str(enemy.id) + ":" + field.tower_id + ":" + field.component.id
			var damage: float = field.damage * elapsed
			# A tower's overlapping copies contribute the strongest single patch.
			if not affected.has(key) or damage > affected[key].damage:
				affected[key] = {"enemy": enemy, "damage": damage, "owner": field.tower_id, "fire": field.fire}
	combat.effect_fields = survivors
	for effect in affected.values():
		combat.hit(effect.enemy, effect.damage, effect.owner, "", effect.fire)
