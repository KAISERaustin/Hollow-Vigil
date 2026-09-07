extends RefCounted

## Reusable presentation component. Each battlefield owns its transient instances.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const DURATION := 0.5
const REVEAL_AT := 0.28
var instances: Array[Dictionary] = []

func play(at: Vector2, owner_id: String = "") -> void:
	remove(at)
	instances.append({"pos": at, "age": 0.0, "owner_id": owner_id})

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
	var release := smoothstep(REVEAL_AT, DURATION, age)
	var pulse := 1.0 + 0.035 * sin(age * TAU * 7.0)
	# A single opaque scalloped silhouette has no translucent overlap seams.
	if release < 1.0:
		# The wider, lower silhouette also covers the terrain's round socket rim.
		cloud(c, Vector2(0, -19 - release * 6), Vector2(42, 48) * (1.0 - release) * pulse)
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
