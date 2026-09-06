extends RefCounted

const Areas = preload("res://scripts/world/hidden_areas.gd")
const STEP := 60.0

# Geometry is planned once per visible sector in local coordinates. Shared
# vertices are exact; damage removes spans, never moves their connection points.
static func build(sector: Vector2i, seed_value: int) -> Dictionary:
	var cells := Areas.cluster(sector, seed_value)
	var anchor := Vector2(cells[0]) * Balance.TILE - Vector2.ONE * 150.0
	var g := Areas.gate(sector, seed_value)
	var gate_point := VigilWorld.center(g.id) + Vector2(VigilWorld.DIRS[g.side]) * 150.0 - anchor
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("castle-plan-v1:" + str(sector) + ":" + str(seed_value)).hash())
	var variant := rng.randi_range(0, 3)
	var occupied := {}
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for cell in cells:
		var base := (cell - cells[0]) * 5
		for y in range(5):
			for x in range(5):
				var p := base + Vector2i(x, y)
				occupied[p] = true
				bounds = bounds.expand(Vector2(p) * STEP).expand(Vector2(p + Vector2i.ONE) * STEP)
	# A courtyard straddles a real shared tile boundary, not a tile center.
	var join := Vector2(cells[1] - cells[0]) * 150.0 + Vector2.ONE * 150.0
	var court := Rect2(join - Vector2(90, 90), Vector2(180, 180))
	var floors: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	var rubble: Array[Vector2] = []
	var towers: Array[Vector2] = []
	var beams: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	for p in occupied:
		var origin := Vector2(p) * STEP
		var middle := origin + Vector2.ONE * 30.0
		var garden := variant == 0 and court.has_point(middle)
		floors.append({"rect": Rect2(origin, Vector2.ONE * STEP), "garden": garden, "shade": rng.randf_range(0.0, 0.018), "crack": rng.randf() < 0.28})
		if variant in [1, 3] and middle.distance_to(gate_point) > 120.0 and rng.randf() < 0.16:
			beams.append({"pos": middle, "angle": rng.randf_range(-1.3, 1.3)})
		for side in range(4):
			var d: Vector2i = VigilWorld.DIRS[side]
			if occupied.has(p + d):
				continue
			var n := Vector2(d)
			var tangent := Vector2(-n.y, n.x)
			var mid := middle + n * 30.0
			var a := mid - tangent * 30.0
			var b := mid + tangent * 30.0
			edges.append({"a": a, "b": b})
			var is_gate := mid.distance_to(gate_point) < 1.0
			# Keep corner spans intact; breaks are confined to straight runs.
			var straight := occupied.has(p + Vector2i(tangent)) and occupied.has(p - Vector2i(tangent)) and not occupied.has(p + d + Vector2i(tangent)) and not occupied.has(p + d - Vector2i(tangent))
			var broken := not is_gate and straight and rng.randf() < 0.18
			if is_gate:
				walls.append({"a": a, "b": a.lerp(b, 0.1), "outer": true})
				walls.append({"a": a.lerp(b, 0.9), "b": b, "outer": true})
			elif broken:
				walls.append({"a": a, "b": a.lerp(b, 0.23), "outer": true})
				walls.append({"a": a.lerp(b, 0.73), "b": b, "outer": true})
				rubble.append(mid)
			else:
				walls.append({"a": a, "b": b, "outer": true})
			# Corner foundations share the same silhouette anchors.
			if not occupied.has(p + Vector2i(tangent)) and rng.randf() < 0.6 and a.distance_to(gate_point) > 90:
				towers.append(a - n * 17.0 + tangent * 17.0)
		# Four genuinely different room plans: courtyard cloister, long hall,
		# close-packed keep chambers, and offset broken residential ranges.
		for side in [2, 3]:
			var d: Vector2i = VigilWorld.DIRS[side]
			if not occupied.has(p + d):
				continue
			var n := Vector2(d)
			var tangent := Vector2(-n.y, n.x)
			var mid := middle + n * 30.0
			var partition := false
			match variant:
				0:
					partition = garden != court.has_point(middle + n * STEP) or (not garden and (posmod(p.x + 1, 3) == 0 if side == 2 else posmod(p.y + 1, 4) == 0))
				1:
					partition = (is_equal_approx(mid.x, snappedf(join.x - 90, STEP)) or is_equal_approx(mid.x, snappedf(join.x + 90, STEP))) if side == 2 else posmod(p.y + 1, 6) == 0
				2:
					partition = posmod(p.x + 1, 2) == 0 if side == 2 else posmod(p.y + 1, 3) == 0
				3:
					partition = posmod(p.x + 1 + floori(float(p.y) / 3), 4) == 0 if side == 2 else posmod(p.y + 1, 3) == 0
			# Protect the whole gate corridor, including the interior spawn.
			var near_gate := Geometry2D.get_closest_point_to_segment(mid, gate_point, gate_point - Vector2(VigilWorld.DIRS[g.side]) * 100.0).distance_to(mid) < 80.0
			if partition and not near_gate:
				if rng.randf() < 0.28:
					rubble.append(mid)
				else:
					walls.append({"a": mid - tangent * 30.0, "b": mid + tangent * rng.randf_range(6, 30), "outer": false})
	return {"cells": cells, "anchor": anchor, "variant": variant, "floors": floors, "walls": walls, "rubble": rubble, "towers": towers, "beams": beams, "edges": edges, "gate": g, "gate_point": gate_point, "bounds": bounds}
