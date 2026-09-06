extends RefCounted

# This is the only projection from local saves to the network. Never serialize
# game.data directly. UUIDs identify entities; they contain no gameplay values.
const FORMAT := 2
const GROUPS := ["progress", "checkpoints", "regions", "unlocks", "towers", "relics", "encounters", "production", "preferences"]
const AUDIO := ["master", "menu", "towers", "enemies", "bosses", "music", "muted"]
const Bosses = preload("res://scripts/gameplay/encounters/bosses.gd")
var error := ""

static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	return _format_uuid(bytes.hex_encode())

static func _format_uuid(h: String) -> String:
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

static func valid_uuid(value: Variant) -> bool:
	if not value is String or value.length() != 36:
		return false
	var h: String = value.replace("-", "")
	return h.length() == 32 and h.is_valid_hex_number() and value == _format_uuid(h)

static func entity_id(world_id: String, category: String, local_id: String = "") -> String:
	# A namespaced UUIDv8 keeps IDs stable without uploading an identity map.
	var bytes := (world_id + "/" + category + "/" + local_id).sha256_buffer().slice(0, 16)
	bytes[6] = (bytes[6] & 15) | 128
	bytes[8] = (bytes[8] & 63) | 128
	return _format_uuid(bytes.hex_encode())

func encode(data: Dictionary, world_id: String, include_audio: bool = false) -> Dictionary:
	error = ""
	if not valid_uuid(world_id) or not VigilSaveStore.new().valid_data(data):
		return _fail("The local save is invalid; cloud upload was skipped.")
	var out := {"format": FORMAT, "world": {"id": world_id, "seed": int(data.seed), "save_version": int(data.version)}}
	for group in GROUPS:
		out[group] = []
	out.world_rules = [{"id": entity_id(world_id, "world_rules"), "mode": data.get("mode", "creative"),
		"setup": data.get("setup", {}), "tuning": data.settings.get("developer_balance", {})}]
	out.progress.append({"id": entity_id(world_id, "progress"), "gold": data.balance, "reserve": data.reserve,
		"lifetime_earnings": data.lifetime_earnings, "kills": data.kills, "escapes": data.escapes,
		"next_tower": int(data.next_tower), "automation": data.automation,
		"first_property_required": data.get("first_property_required", false)})
	out.checkpoints.append({"id": entity_id(world_id, "checkpoint"), "last_accounted": data.last_accounted, "active_seconds": data.active_seconds})
	for key in data.regions:
		var r: Dictionary = data.regions[key]
		var rid := entity_id(world_id, "region", key)
		var parent_id: Variant = null
		if r.parent != "":
			parent_id = entity_id(world_id, "region", r.parent)
		out.regions.append({"id": rid, "local_key": key, "parent_id": parent_id,
			"side": int(r.side), "bend": int(r.bend), "traffic": int(r.traffic), "style": r.get("style", "forest"), "road_version": int(r.get("road_version", 2)), "history_time": r.history_time})
		for kind in r.unlocks:
			out.unlocks.append({"id": entity_id(world_id, "unlock", key + "/" + kind), "region_id": rid, "kind": kind})
		for tower_id in r.history:
			out.production.append({"id": entity_id(world_id, "production", key + "/" + tower_id), "region_id": rid,
				"tower_id": entity_id(world_id, "tower", tower_id), "earned": r.history[tower_id]})
	for key in data.towers:
		var t: Dictionary = data.towers[key]
		var relic_id: Variant = null
		if t.get("relic", "") != "":
			relic_id = entity_id(world_id, "relic", t.relic)
		out.towers.append({"id": entity_id(world_id, "tower", key), "local_key": key,
			"region_id": entity_id(world_id, "region", t.region), "kind": t.kind, "pad": int(t.pad),
			"level": int(t.level), "branch": t.get("branch", ""), "earnings": t.earnings,
			"target_mode": t.get("target_mode", "first"), "rebuild_remaining": t.get("rebuild_remaining", 0.0),
			"relic_id": relic_id})
	for key in data.get("relics", {}):
		out.relics.append({"id": entity_id(world_id, "relic", key), "source_key": key, "kind": data.relics[key]})
	for is_castle in [false, true]:
		var records: Dictionary = data.get("castles", {}) if is_castle else data.regions
		for key in records:
			if not records[key].has("boss"):
				continue
			var b: Dictionary = records[key].boss
			var row := {"id": entity_id(world_id, "encounter", key), "source_key": key, "is_castle": is_castle, "kind": b.kind, "status": b.status}
			for field in ["hp", "tile", "previous", "steps", "shield", "wards", "regen", "toll", "toll_delayed", "segment"]:
				row[field] = b.get(field) if b.status == "active" else null
			for field in ["steps", "wards", "segment"]:
				if row[field] != null:
					row[field] = int(row[field])
			row.pos_x = b.pos[0] if b.status == "active" else null
			row.pos_y = b.pos[1] if b.status == "active" else null
			row.emergence = b.status == "active" and is_castle and b.steps == 1 and b.path.size() == 27
			out.encounters.append(row)
	if include_audio and data.settings.has("audio"):
		var row := {"id": entity_id(world_id, "preferences")}
		for field in AUDIO:
			row[field] = data.settings.audio.get(field, false if field == "muted" else preload("res://scripts/audio/audio_director.gd").DEFAULTS[field])
		out.preferences.append(row)
	return out

func decode(payload: Variant, local_settings: Dictionary = {}, local_camera: Array = [0.0, 0.0, 1.0], include_audio: bool = false) -> Dictionary:
	error = ""
	if not _shape(payload):
		return _fail("The cloud save has an unsupported or invalid format. Local progress is safe.")
	var d: Dictionary = VigilState.new(int(payload.world.seed)).data.duplicate(true)
	d.settings = local_settings.duplicate(true)
	d.settings.erase("developer_balance")
	if int(payload.format) == FORMAT:
		var rules: Dictionary = payload.world_rules[0]
		d.mode = rules.mode
		d.settings.developer_balance = rules.tuning.duplicate(true)
		if not rules.setup.is_empty(): d.setup = rules.setup.duplicate(true)
	d.settings.low_power = d.settings.get("low_power", false)
	d.camera = local_camera.duplicate()
	d.regions = {}
	d.towers = {}
	d.castles = {}
	d.relics = {}
	var p: Dictionary = payload.progress[0]
	d.balance = p.gold
	for field in ["reserve", "lifetime_earnings", "kills", "escapes", "next_tower", "automation", "first_property_required"]:
		d[field] = p[field]
	d.last_accounted = payload.checkpoints[0].last_accounted
	d.active_seconds = payload.checkpoints[0].active_seconds
	var region_keys := {}
	var tower_keys := {}
	var relic_keys := {}
	for r in payload.regions:
		if d.regions.has(r.local_key):
			return _fail("Duplicate cloud territory.")
		region_keys[r.id] = r.local_key
		d.regions[r.local_key] = {"id": r.local_key, "parent": "", "side": r.side, "bend": float(r.bend),
			"traffic": r.traffic, "style": r.style, "road_version": r.road_version, "timer": 0.0,
			"unlocks": [], "history": {}, "history_time": r.history_time}
	for r in payload.regions:
		if r.parent_id != null and not region_keys.has(r.parent_id):
			return _fail("Cloud territory references a missing parent.")
		d.regions[r.local_key].parent = region_keys.get(r.parent_id, "")
	for r in payload.relics:
		if d.relics.has(r.source_key):
			return _fail("Duplicate cloud relic.")
		relic_keys[r.id] = r.source_key
		d.relics[r.source_key] = r.kind
	for t in payload.towers:
		if not region_keys.has(t.region_id) or (t.relic_id != null and not relic_keys.has(t.relic_id)) or d.towers.has(t.local_key):
			return _fail("Cloud tower references are invalid.")
		tower_keys[t.id] = t.local_key
		d.towers[t.local_key] = {"id": t.local_key, "kind": t.kind, "region": region_keys[t.region_id],
			"pad": t.pad, "level": t.level, "branch": t.branch, "earnings": t.earnings,
			"target_mode": t.target_mode, "rebuild_remaining": t.rebuild_remaining,
			"relic": relic_keys.get(t.relic_id, ""), "cooldown": 0.0, "angle": 0.0}
	for row in payload.unlocks:
		if not region_keys.has(row.region_id):
			return _fail("Cloud unlock references a missing territory.")
		d.regions[region_keys[row.region_id]].unlocks.append(row.kind)
	for row in payload.production:
		if not region_keys.has(row.region_id) or not tower_keys.has(row.tower_id):
			return _fail("Cloud production references a missing tower or territory.")
		var r: Dictionary = d.regions[region_keys[row.region_id]]
		if r.history.has(tower_keys[row.tower_id]):
			return _fail("Cloud production samples are inconsistent.")
		r.history[tower_keys[row.tower_id]] = row.earned
	# Validate the territory graph BEFORE using it to reconstruct any boss path.
	if not VigilSaveStore.new().valid_data(d):
		return _fail("Cloud progress failed save validation. Local progress is safe.")
	for row in payload.encounters:
		if not row.is_castle and not d.regions.has(row.source_key):
			return _fail("Cloud encounter references a missing territory.")
		var b := {"kind": row.kind, "status": row.status}
		if row.status == "active":
			for field in ["hp", "tile", "previous", "steps", "shield", "wards", "regen", "toll", "toll_delayed", "segment"]:
				b[field] = row[field]
			if not d.regions.has(b.tile) or not VigilSaveStore.new().valid_coordinate(b.previous):
				return _fail("Cloud encounter route is invalid.")
			var path: Array[Vector2] = []
			if row.emergence:
				var gate := Bosses.Areas.gate(Bosses.Areas.sector_for(VigilWorld.coord(b.previous)), int(d.seed))
				if gate.id != row.source_key or gate.neighbor != b.tile:
					return _fail("Cloud castle route is invalid.")
				path = Bosses.Areas.emergence(gate, d.regions)
			else:
				var side := VigilWorld.DIRS.find(VigilWorld.coord(b.tile) - VigilWorld.coord(b.previous))
				if not d.regions.has(b.previous) or side < 0:
					return _fail("Cloud encounter route is disconnected.")
				path = VigilWorld.spoke(d.regions[b.previous], side)
				path.reverse()
				path.append_array(VigilWorld.spoke(d.regions[b.tile], (side + 2) % 4).slice(1))
			b.path = []
			for point in path:
				b.path.append([point.x, point.y])
			b.pos = [row.pos_x, row.pos_y]
		if row.is_castle:
			if d.castles.has(row.source_key):
				return _fail("Duplicate cloud castle.")
			d.castles[row.source_key] = {"boss": b}
		else:
			if d.regions[row.source_key].has("boss"):
				return _fail("Duplicate cloud encounter.")
			d.regions[row.source_key].boss = b
	if include_audio and not payload.preferences.is_empty():
		d.settings.audio = {}
		for field in AUDIO:
			d.settings.audio[field] = payload.preferences[0][field]
	if not VigilSaveStore.new().valid_data(d):
		return _fail("Cloud encounter or preference validation failed. Local progress is safe.")
	return d

func _fail(message: String) -> Dictionary:
	error = message
	return {}

func _shape(p: Variant) -> bool:
	if not p is Dictionary or (p.get("format") != 1 and p.get("format") != FORMAT) or not p.get("world") is Dictionary:
		return false
	if not _record(p.world, {"id": "uuid", "seed": "number", "save_version": "number"}) or p.world.save_version != Balance.VERSION:
		return false
	var modern := int(p.format) == FORMAT
	if p.size() != GROUPS.size() + (3 if modern else 2):
		return false
	if modern:
		if not p.get("world_rules") is Array or p.world_rules.size() != 1:
			return false
		var rules: Variant = p.world_rules[0]
		if not rules is Dictionary or rules.size() != 4 or not valid_uuid(rules.get("id")):
			return false
		if rules.get("mode") not in ["creative", "survival"] or not rules.get("setup") is Dictionary or not rules.get("tuning") is Dictionary:
			return false
		if not Balance.valid_tuning(rules.tuning): return false
		if not rules.setup.is_empty():
			if rules.setup.size() != 2 or not rules.setup.get("name") is String or not rules.setup.get("description") is String:
				return false
			if rules.setup.name.strip_edges().is_empty() or rules.setup.name.length() > 80 or rules.setup.description.length() > 4000:
				return false
	var shapes := {
		"progress": {"id": "uuid", "gold": "number", "reserve": "number", "lifetime_earnings": "number", "kills": "number", "escapes": "number", "next_tower": "number", "automation": "bool", "first_property_required": "bool"},
		"checkpoints": {"id": "uuid", "last_accounted": "number", "active_seconds": "number"},
		"regions": {"id": "uuid", "local_key": "string", "parent_id": "uuid?", "side": "number", "bend": "number", "traffic": "number", "style": "string", "road_version": "number", "history_time": "number"},
		"unlocks": {"id": "uuid", "region_id": "uuid", "kind": "string"},
		"towers": {"id": "uuid", "local_key": "string", "region_id": "uuid", "kind": "string", "pad": "number", "level": "number", "branch": "string", "earnings": "number", "target_mode": "string", "rebuild_remaining": "number", "relic_id": "uuid?"},
		"relics": {"id": "uuid", "source_key": "string", "kind": "string"},
		"encounters": {"id": "uuid", "source_key": "string", "is_castle": "bool", "kind": "string", "status": "string", "hp": "number?", "tile": "string?", "previous": "string?", "steps": "number?", "shield": "number?", "wards": "number?", "regen": "number?", "toll": "number?", "toll_delayed": "bool?", "segment": "number?", "pos_x": "number?", "pos_y": "number?", "emergence": "bool"},
		"production": {"id": "uuid", "region_id": "uuid", "tower_id": "uuid", "earned": "number"},
		"preferences": {"id": "uuid", "master": "number", "menu": "number", "towers": "number", "enemies": "number", "bosses": "number", "music": "number", "muted": "bool"}}
	var ids := {p.world.id: true}
	if modern:
		if ids.has(p.world_rules[0].id): return false
		ids[p.world_rules[0].id] = true
	for group in GROUPS:
		if not p.get(group) is Array or p[group].size() > 10000:
			return false
		for row in p[group]:
			if not _record(row, shapes[group]) or ids.has(row.id):
				return false
			ids[row.id] = true
			if group == "encounters" and row.status == "active":
				for key in shapes[group]:
					if row[key] == null:
						return false
	return p.progress.size() == 1 and p.checkpoints.size() == 1 and p.preferences.size() <= 1

func _record(row: Variant, shape: Dictionary) -> bool:
	if not row is Dictionary or row.size() != shape.size():
		return false
	for key in shape:
		if not row.has(key):
			return false
		var value: Variant = row[key]
		var kind: String = shape[key]
		if kind.ends_with("?") and value == null:
			continue
		match kind.trim_suffix("?"):
			"uuid":
				if not valid_uuid(value): return false
			"number":
				if not (value is int or value is float) or not is_finite(value): return false
			"bool":
				if not value is bool: return false
			"string":
				if not value is String or value.length() > 128: return false
	return true
