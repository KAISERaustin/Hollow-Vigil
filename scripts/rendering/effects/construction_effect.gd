extends RefCounted

## Reusable presentation component. Each battlefield owns its transient instances.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const DURATION := 0.9
const REVEAL_AT := 0.52
var instances: Array[Dictionary] = []

func play(at: Vector2, accent: Color, owner_id: String = "") -> void:
	remove(at)
	instances.append({"pos": at, "age": 0.0, "color": Color(accent, 1.0), "owner_id": owner_id})

func remove(at: Vector2) -> void:
	for i in range(instances.size() - 1, -1, -1):
		if instances[i].pos == at:
			instances.remove_at(i)

func clear() -> void:
	instances.clear()

func advance(delta: float) -> void:
	for i in range(instances.size() - 1, -1, -1):
		instances[i].age += maxf(0.0, delta)
		if instances[i].age >= DURATION:
			instances.remove_at(i)

func conceals(at: Vector2) -> bool:
	for fx in instances:
		if fx.pos == at and fx.age < REVEAL_AT:
			return true
	return false

static func draw(c: CanvasItem, fx: Dictionary, at: Vector2, zoom: float) -> void:
	var age: float = fx.age
	if age < 0.0 or age >= DURATION:
		return
	c.draw_set_transform(at, 0.0, Vector2.ONE * zoom)
	var release := smoothstep(REVEAL_AT, 0.84, age)
	var pulse := 1.0 + 0.035 * sin(age * TAU * 7.0)
	# A single opaque scalloped silhouette has no translucent overlap seams.
	if release < 1.0:
		cloud(c, Vector2(0, -24 - release * 9), Vector2(35, 43) * (1.0 - release) * pulse)
	# Solid dust lobes peel away and shrink, rather than fading through the tower.
	for side in [-1, 1]:
		for i in range(3):
			var radius := (7.0 + i * 1.5) * sin(clampf(age / 0.86, 0.0, 1.0) * PI)
			if release > 0.0 and radius > 0.2:
				var p := Vector2(side * (25.0 + release * (12 + i * 4)), -5.0 - i * 19.0 - release * 8)
				Art.disk(c, p, radius, Art.PAPER, 1.5 * minf(1.0, radius / 3.0))
		var worker_scale := 1.0 - smoothstep(0.68, DURATION, age)
		if worker_scale > 0.01:
			var phase := fposmod(age * 4.0 + (0.35 if side == 1 else 0.0), 1.0)
			worker(c, Vector2(side * (38.0 + release * 5.0), 12), side, worker_scale, phase, fx.color)
	c.draw_set_transform(Vector2.ZERO)

static func cloud(c: CanvasItem, at: Vector2, radius: Vector2) -> void:
	var size := radius.x / 35.0
	var lobes: Array[Vector2] = []
	for i in range(9):
		var angle := TAU * i / 9.0
		lobes.append(at + Vector2.from_angle(angle) * radius * Vector2(0.68,0.71))
	# Outline the union first, then fill the entire cloud with solid parchment.
	Art.ellipse(c, at, radius * 0.8, Art.INK, 0)
	for i in range(lobes.size()):
		c.draw_circle(lobes[i], (12.5 + (i % 3) * 1.2) * size, Art.INK)
	Art.ellipse(c, at, radius * 0.8, Art.PAPER, 0)
	for i in range(lobes.size()):
		c.draw_circle(lobes[i], (10.7 + (i % 3) * 1.2) * size, Art.PAPER)
	if radius.x > 12.0:
		c.draw_arc(at + Vector2(-15,-12) * size, 8 * size, -2.4, 0.5, 12, Art.ROAD, 1.8 * size, true)
		c.draw_arc(at + Vector2(16,13) * size, 7 * size, 0.4, 3.2, 12, Art.ROAD, 1.8 * size, true)

static func worker(c: CanvasItem, at: Vector2, side: int, scale: float, phase: float, accent: Color) -> void:
	# The same tiny villager is mirrored to face the work on either side.
	var z := Vector2(-side, 1) * scale
	var bob := Vector2(0, sin(phase * PI) * 1.2)
	at += bob * scale
	for foot in [-1, 1]:
		c.draw_line(at + Vector2(foot * 2, -5) * z, at + Vector2(foot * 3, 0) * z, Art.INK, 2.5 * scale, true)
	Art.shape(c, [Vector2(-4,-14), Vector2(3,-14), Vector2(5,-5), Vector2(-5,-5)], at, z, accent, 1.5 * scale)
	Art.disk(c, at + Vector2(0,-19) * z, 4.5 * scale, Art.PAPER, 1.5 * scale)
	Art.shape(c, [Vector2(-5,-21), Vector2(-3,-25), Vector2(2,-25), Vector2(5,-21)], at, z, Art.ROAD, 1.3 * scale)
	c.draw_circle(at + Vector2(2,-19) * z, 0.9 * scale, Art.INK)
	# Fast downstroke, longer backswing: two clearly readable alternating taps.
	var swing := smoothstep(0.0, 0.3, phase) * (1.0 - smoothstep(0.42, 1.0, phase))
	var hand := Vector2(4,-13)
	var head := hand + Vector2.from_angle(lerpf(-1.8, -0.12, swing)) * 12.0
	c.draw_line(at + Vector2(0,-13) * z, at + hand * z, Art.INK, 3 * scale, true)
	c.draw_line(at + hand * z, at + head * z, Art.INK, 2.8 * scale, true)
	Art.shape(c, [head+Vector2(-3,-3), head+Vector2(4,-3), head+Vector2(4,2), head+Vector2(-3,2)], at, z, Art.ROAD, 1.5 * scale)
	if phase > 0.28 and phase < 0.43:
		for i in range(3):
			var ray := Vector2.from_angle(-1.5 + i * 0.7)
			c.draw_line(at + (head + ray * 5) * z, at + (head + ray * 8) * z, Art.GOLD, 1.5 * scale, true)
