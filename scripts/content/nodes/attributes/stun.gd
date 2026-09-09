extends "res://scripts/content/nodes/attribute_node.gd"

func prepare(_state: Dictionary, context: Dictionary, stats: Dictionary, config: Dictionary) -> void:
	if active(context, config):
		effect(stats, config)

func impact(combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	if config.get("area_radius", 0.0) > 0.0 or enemy.id != shot.get("target_id", -1):
		return
	apply(combat, shot, enemy, config)

func arrive(combat, shot: Dictionary, config: Dictionary) -> void:
	var radius: float = config.get("area_radius", 0.0)
	if radius <= 0.0:
		return
	for enemy in combat.nearby_enemies(shot.fx.pos, radius):
		if not enemy.dead and enemy.pos.distance_squared_to(shot.fx.pos) <= radius * radius:
			apply(combat, shot, enemy, config)
	combat.add_effect({"kind": "gear_stun", "pos": shot.fx.pos, "radius": radius, "life": 0.4, "max_life": 0.4, "color": "acd6cf"})

func apply(combat, shot: Dictionary, enemy: Dictionary, config: Dictionary) -> void:
	if enemy.dead or enemy.get("gear_stun_immune_until", 0.0) > combat.simulation_time:
		return
	var duration: float = config.boss_duration if enemy.get("boss", false) else config.duration
	var status := {"type": "stun", "until": combat.simulation_time + duration}
	if config.has("direct_assignment"):
		status.tower_epoch = config.tower_epoch
		status.component = self
	combat.Relics.add_status(enemy, shot.tower_id, id, status)
	enemy.gear_stun_immune_until = combat.simulation_time + config.stun_immunity
