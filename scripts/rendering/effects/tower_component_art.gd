extends RefCounted

const A = preload("res://scripts/rendering/terrain/terrain_art.gd")
const Towers = preload("res://scripts/rendering/actors/expansion_tower_art.gd")

static func draw(field) -> void:
	var combat = field.state.combat
	var zoom: float = field.zoom
	var view := Rect2(Vector2(-80, -80), field.size + Vector2(160, 160))
	for trap in combat.traps:
		var at: Vector2 = field.screen(trap.pos)
		if not view.has_point(at): continue
		field.draw_set_transform(at, 0.0, Vector2.ONE * zoom)
		var armed: bool = combat.simulation_time >= trap.arm_at
		A.ellipse(field, Vector2(0, 2), Vector2(9, 4), A.PAPER if armed else A.ROAD, 1.5)
		if trap.branch == "dreadjaw":
			Towers.poly(field, [Vector2(-10, -4), Vector2(-6, 3), Vector2(-2, -3), Vector2(2, 3), Vector2(6, -3), Vector2(10, 3)], Towers.BONE)
		else: Towers.spike(field, Vector2.ZERO, 7 if armed else 4)
		field.draw_set_transform(Vector2.ZERO)
	for projectile in combat.line_projectiles:
		var at: Vector2 = field.screen(projectile.pos)
		if not view.has_point(at): continue
		var angle: float = projectile.age * 12.0 if projectile.returning else projectile.direction.angle()
		field.draw_set_transform(at, angle, Vector2.ONE * zoom)
		if projectile.returning:
			Towers.crescent(field, Vector2.ZERO, projectile.width * 0.7, A.MINT)
		else:
			Towers.poly(field, [Vector2(-14,-2),Vector2(5,-2),Vector2(5,-5),Vector2(15,0),Vector2(5,5),Vector2(5,2),Vector2(-14,2)], Towers.BONE)
		field.draw_set_transform(Vector2.ZERO)
	for tower in field.state.data.towers.values():
		if tower.get("rebuild_remaining", 0.0) > 0.0: continue
		var node = combat.TowerComponents.definition(combat, tower)
		if node == null: continue # Legacy/editor previews may omit a level-four branch.
		var orbit := false
		for entry in node.rule("components", []):
			if entry.component.rule("presentation", "") == "orbit": orbit = true
		if not orbit: continue
		var origin: Vector2 = VigilWorld.pad_position(tower.region, tower.pad)
		var stats: Dictionary = Balance.tower_stats(tower, combat.tuning, combat.data.relics)
		for blade in range(3):
			var angle: float = combat.simulation_time * TAU / stats.period + blade * TAU / 3.0
			var at: Vector2 = field.screen(origin + Vector2.from_angle(angle) * stats.range * 0.85)
			if not view.has_point(at): continue
			field.draw_set_transform(at, angle, Vector2.ONE * zoom)
			Towers.crescent(field, Vector2.ZERO, 9, A.MINT)
			field.draw_set_transform(Vector2.ZERO)
