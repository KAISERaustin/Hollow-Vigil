extends "res://scripts/content/nodes/attribute_node.gd"

func ready(_combat, _tower: Dictionary, _origin: Vector2, _stats: Dictionary) -> bool:
	return true

func attack(combat, tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	var snapshot: Array = combat.TowerComponents.snapshot(combat, tower, stats)
	var primary := true
	for enemy in combat.nearby_enemies(origin, stats.range):
		if enemy.dead: continue
		var shot := combat.Projectiles.make_shot(combat, tower, origin, enemy, stats, primary)
		shot.fx.pos = enemy.pos
		shot.tower_effects = snapshot
		combat.resolve_shot(shot, enemy)
		primary = false
	combat.add_effect({"kind": "orbit_sweep", "pos": origin, "radius": stats.range, "color": stats.color, "life": 0.2, "max_life": 0.2})
