class_name VigilWorld
extends RefCounted

const DIRS := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]
const PADS = preload("res://scripts/content/catalogs/world.gd").PADS
const CORE_POSITION := Vector2.ZERO
const STYLES = preload("res://scripts/content/catalogs/world.gd").STYLES
const NEW_STYLES = preload("res://scripts/content/catalogs/world.gd").NEW_STYLES
const ALL_STYLES = preload("res://scripts/content/catalogs/world.gd").ALL_STYLES

static func key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]

static func coord(id: String) -> Vector2i:
	var parts := id.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func center(id: String) -> Vector2:
	return Vector2(coord(id)) * Balance.TILE

static func make_region(id: String, parent: String, _seed_value: int) -> Dictionary:
	return Balance.Content.region("forest").create(id, parent, 0, 24.0)

static func pad_position(region: String, pad: int) -> Vector2:
	if pad < 4:
		return center(region) + PADS[pad]
	var packed := pad - 4
	return center(region) + Vector2(packed % 3000, floori(packed / 3000.0)) * 0.1 - Vector2.ONE * 150.0

# Legacy 0..3 locations remain stable; ground keys encode tenths of a unit.
const MAX_GROUND_PAD := 9000003

static func ground_location(point: Vector2) -> Dictionary:
	var cell := Vector2i(floori((point.x + 150.0) / 300.0), floori((point.y + 150.0) / 300.0))
	var region := key(cell)
	var local := (point - center(region) + Vector2.ONE * 150.0) * 10.0
	return {"region": region, "pad": 4 + clampi(roundi(local.x), 0, 2999) + clampi(roundi(local.y), 0, 2999) * 3000}
