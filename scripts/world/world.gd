class_name VigilWorld
extends RefCounted

const DIRS := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]
const PADS = preload("res://scripts/content/catalogs/world.gd").PADS
const CORE_POSITION := Vector2.ZERO
const STYLES = preload("res://scripts/content/catalogs/world.gd").STYLES
const NEW_STYLES = preload("res://scripts/content/catalogs/world.gd").NEW_STYLES
const ALL_STYLES = preload("res://scripts/content/catalogs/world.gd").ALL_STYLES
const Orchard = preload("res://scripts/world/mourning_orchard.gd")

static func is_starter(id: String) -> bool:
	var radius: int = Balance.Content.catalog().get_node("level/open_world").rule("starter_radius")
	var cell := coord(id)
	return maxi(absi(cell.x), absi(cell.y)) <= radius

static func is_ruin(id: String, seed_value: int) -> bool:
	var areas = preload("res://scripts/world/hidden_areas.gd")
	return areas.cluster(areas.sector_for(coord(id)), seed_value).has(coord(id))

static func region_style(id: String, seed_value: int) -> String:
	if is_starter(id):
		return Balance.Content.catalog().get_node("level/open_world").rule("starter_style")
	if Orchard.cluster(seed_value).has(coord(id)):
		return Orchard.STYLE
	if is_ruin(id, seed_value):
		return "castle_ruin"
	return STYLES[preload("res://scripts/world/terrain_clusters.gd").style_index(coord(id), seed_value)]

static func key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]

static func coord(id: String) -> Vector2i:
	var parts := id.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func center(id: String) -> Vector2:
	return Vector2(coord(id)) * Balance.TILE

static func has_rift(id: String, regions: Dictionary = {}, seed_value: int = -1) -> bool:
	# The core already has its receiving portal; it never spawns onto itself.
	if id == "0,0":
		return false
	if not regions.is_empty() and not regions.has(id):
		return false
	# Derive this from the seed for old saves as well as newly claimed land.
	if seed_value >= 0 and regions.get(id, {}).get("style", "forest") == "castle_ruin" and is_ruin(id, seed_value):
		return is_dungeon_portal(id, seed_value)
	return true

static func is_dungeon_portal(id: String, seed_value: int) -> bool:
	var areas = preload("res://scripts/world/hidden_areas.gd")
	return areas.gate(areas.sector_for(coord(id)), seed_value).id == id

static func make_region(id: String, parent: String, seed_value: int) -> Dictionary:
	var h := absi((id + str(seed_value)).hash())
	var side := h % 4
	if parent != "":
		var outward := coord(id) - coord(parent)
		side = DIRS.find(outward)
	else:
		side = 0
	return Balance.Content.region("forest" if parent == "" else region_style(id, seed_value)).create(id, parent, side, -24.0 if h % 2 == 0 else 24.0)

# Every tile owns immutable roads with shared edge centers and edge tangents.
# Routing uses every owned neighbor, independently of the expansion parent.
static func spoke(region: Dictionary, side: int) -> Array[Vector2]:
	if int(region.get("road_version", 2)) >= 2:
		return curved_spoke(region, side)
	return legacy_spoke(region, side)

static func curved_spoke(region: Dictionary, side: int) -> Array[Vector2]:
	var c := center(region.id)
	var outward := Vector2(DIRS[side])
	var tangent := Vector2(-outward.y, outward.x)
	var pattern := absi((region.id + ":" + str(int(region.bend)) + ":" + str(side)).hash())
	var amplitude := (25.0 + float(pattern % 9)) * (-1.0 if pattern % 2 == 0 else 1.0)
	var result: Array[Vector2] = []
	for i in range(25):
		var t := i / 24.0
		var bend := sin(PI * t) * sin(PI * t)
		if pattern % 3 != 0:
			bend = sin(TAU * t) * sin(PI * t)
		result.append(c + outward * (150.0 * (1.0 - t)) + tangent * amplitude * bend)
	# Exact endpoints keep seams and the final core escape numerically identical.
	result[0] = c + outward * Balance.TILE * 0.5
	result[-1] = c
	return result

static func legacy_spoke(region: Dictionary, side: int) -> Array[Vector2]:
	var c := center(region.id)
	var gate: Vector2 = c + Vector2(DIRS[side]) * Balance.TILE * 0.5
	if side == 0 or side == 2:
		return [gate, c]
	return [gate, c + Vector2(0, region.bend + (-55.0 if side == 1 else 55.0)), c + Vector2(region.bend, region.bend + (-55.0 if side == 1 else 55.0)), c + Vector2(region.bend, 0), c]

static func shortest_exits(regions: Dictionary) -> Dictionary:
	# Count tile crossings, so decorative road bends cannot break a logical tie.
	# Breadth-first order also puts each exit before the tiles that lead to it.
	if not regions.has("0,0"):
		return {}
	var distances := {"0,0": 0}
	var queue: Array[String] = ["0,0"]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for direction in DIRS:
			var neighbor := key(coord(id) + direction)
			if regions.has(neighbor) and not distances.has(neighbor):
				distances[neighbor] = distances[id] + 1
				queue.append(neighbor)
	var exits := {}
	for id in queue:
		var choices: Array[String] = []
		for direction in DIRS:
			var neighbor := key(coord(id) + direction)
			if distances.has(neighbor) and distances[neighbor] == distances[id] - 1:
				choices.append(neighbor)
		exits[id] = choices
	return exits

static func route(regions: Dictionary, id: String, exits: Dictionary = {}, rng: RandomNumberGenerator = null) -> Array[Vector2]:
	if exits.is_empty():
		exits = shortest_exits(regions)
	if not exits.has(id):
		return []
	var result: Array[Vector2] = [center(id)]
	var cursor := id
	var visited := {}
	while cursor != "0,0":
		if visited.has(cursor):
			return []
		visited[cursor] = true
		var r: Dictionary = regions[cursor]
		var choices: Array = exits.get(cursor, [])
		if choices.is_empty():
			return []
		# Choose independently for each enemy at every fork along its route.
		var next: String = choices[rng.randi_range(0, choices.size() - 1) if rng != null and choices.size() > 1 else 0]
		var direction := DIRS.find(coord(next) - coord(cursor))
		var leave := spoke(r, direction)
		leave.reverse()
		result.append_array(leave.slice(1))
		var enter := spoke(regions[next], (direction + 2) % 4)
		result.append_array(enter.slice(1))
		cursor = next
	return without_backtracking(result)

static func without_backtracking(path: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in path:
		# Spokes can share a stretch of road before reaching the tile center.
		# Turn at that junction instead of visiting the center and retracing it.
		while result.size() >= 2:
			var incoming := result[-1] - result[-2]
			var outgoing := point - result[-1]
			if not is_zero_approx(incoming.cross(outgoing)) or incoming.dot(outgoing) >= 0.0:
				break
			result.pop_back()
		if result.is_empty() or not result[-1].is_equal_approx(point):
			result.append(point)
	return result

static func frontier(regions: Dictionary, _seed_value: int = -1) -> Dictionary:
	var result := {}
	for id in regions:
		for d in DIRS:
			var candidate := key(coord(id) + d)
			if not regions.has(candidate) and not result.has(candidate):
				result[candidate] = id
	return result

static func pad_position(region: String, pad: int) -> Vector2:
	if pad < 4:
		return center(region) + PADS[pad]
	var packed := pad - 4
	return center(region) + Vector2(packed % 3000, packed / 3000) * 0.1 - Vector2.ONE * 150.0

# Legacy 0..3 locations remain stable; ground keys encode tenths of a unit.
const MAX_GROUND_PAD := 9000003

static func ground_location(point: Vector2) -> Dictionary:
	var cell := Vector2i(floori((point.x + 150.0) / 300.0), floori((point.y + 150.0) / 300.0))
	var region := key(cell)
	var local := (point - center(region) + Vector2.ONE * 150.0) * 10.0
	return {"region": region, "pad": 4 + clampi(roundi(local.x), 0, 2999) + clampi(roundi(local.y), 0, 2999) * 3000}
