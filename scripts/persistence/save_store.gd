class_name VigilSaveStore
extends RefCounted

var last_error := ""

func write(path: String, data: Dictionary) -> bool:
	# Validate before opening .tmp: it may be the only recoverable snapshot.
	if not valid_data(data):
		last_error = "Couldn't save invalid progress. Your previous save is safe."
		return false
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"payload": payload, "checksum": payload.sha256_text()})
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		last_error = "Couldn't save your progress. Keep the game open while we try again."
		return false
	f.store_string(envelope)
	f.flush()
	f.close()
	if read_candidate(path + ".tmp").is_empty():
		last_error = "Couldn't update your save. Your previous save is safe."
		return false
	if FileAccess.file_exists(path) and not read_candidate(path).is_empty():
		var backup_error := DirAccess.rename_absolute(path, path + ".bak")
		if backup_error != OK:
			last_error = "Couldn't update your save. A recovery copy is available."
			return false
	var err := DirAccess.rename_absolute(path + ".tmp", path)
	last_error = "" if err == OK else "Saving was interrupted. A recovery copy is available."
	return err == OK

func read_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or not valid_data(parsed):
		return {}
	return parsed

func valid_data(d: Dictionary) -> bool:
	for field in ["version", "sequence", "seed", "balance", "reserve", "lifetime_earnings", "kills", "escapes", "regions", "towers", "next_tower", "automation", "last_accounted", "active_seconds", "settings", "camera"]:
		if not d.has(field):
			return false
	if d.version != Balance.VERSION or not d.regions is Dictionary or not d.towers is Dictionary or not d.regions.has("0,0"):
		return false
	for field in ["balance", "reserve", "lifetime_earnings", "kills", "escapes", "last_accounted", "active_seconds"]:
		if not number(d[field]):
			return false
	if not number(d.sequence, 0, 1.0e15, true) or not number(d.seed, 0, 1.0e15, true) or not number(d.next_tower, 1, 1.0e15, true):
		return false
	if not d.automation is bool or not d.settings is Dictionary or not d.camera is Array or d.camera.size() != 3:
		return false
	if not d.settings.get("low_power") is bool:
		return false
	if not number(d.camera[0], -1.0e12, 1.0e12) or not number(d.camera[1], -1.0e12, 1.0e12) or not number(d.camera[2], 0.42, 1.65):
		return false
	# Validate every region's shape before walking any parent chain.
	for id in d.regions:
		var r = d.regions[id]
		if not valid_coordinate(id) or not r is Dictionary:
			return false
		for field in ["id", "parent", "side", "bend", "traffic", "timer", "unlocks", "history", "history_time"]:
			if not r.has(field):
				return false
		if r.id != id or not r.parent is String or (r.parent != "" and not d.regions.has(r.parent)):
			return false
		if r.has("style") and (not r.style is String or (r.style != "forest" and not r.style in VigilWorld.NEW_STYLES)):
			return false
		if r.has("road_version") and not number(r.road_version, 1, 2, true):
			return false
		if (id == "0,0") != (r.parent == ""):
			return false
		if r.parent != "":
			if not valid_coordinate(r.parent) or Vector2(VigilWorld.coord(id) - VigilWorld.coord(r.parent)).length() != 1.0:
				return false
		if not number(r.side, 0, 3, true) or not number(r.traffic, 0, Balance.MAX_TRAFFIC_LEVEL, true) or not r.bend in [-24.0, 24.0]:
			return false
		if not number(r.timer, -10, 10) or not number(r.history_time, 0, Balance.HISTORY_SECONDS) or not r.history is Dictionary or not r.unlocks is Array:
			return false
		var seen_unlocks := {}
		for kind in r.unlocks:
			if not kind is String or not Balance.UNLOCK_COSTS.has(kind) or seen_unlocks.has(kind):
				return false
			seen_unlocks[kind] = true
		for value in r.history.values():
			if not number(value):
				return false
	var occupied := {}
	for id in d.towers:
		var t = d.towers[id]
		if not t is Dictionary or not id is String or not id.is_valid_int():
			return false
		if int(id) < 1 or str(int(id)) != id:
			return false
		for field in ["id", "kind", "region", "pad", "level", "earnings", "cooldown", "angle"]:
			if not t.has(field):
				return false
		if t.id != id or int(id) >= d.next_tower or not Balance.TOWERS.has(t.kind) or not d.regions.has(t.region):
			return false
		if not number(t.pad, 0, 3, true) or not number(t.level, 1, Balance.MAX_TOWER_LEVEL, true) or not number(t.earnings) or not number(t.cooldown, 0, 10) or not number(t.angle, -TAU, TAU):
			return false
		var socket := str(t.region) + "/" + str(int(t.pad))
		if occupied.has(socket):
			return false
		occupied[socket] = true
	# Parent links describe purchase history, not enemy routes. Validate them
	# separately now that movement can also use non-parent neighbors.
	var rooted := {"0,0": true}
	for id in d.regions:
		var chain := {}
		var cursor: String = id
		while not rooted.has(cursor):
			if chain.has(cursor):
				return false
			chain[cursor] = true
			cursor = d.regions[cursor].parent
		rooted.merge(chain)
		for tower_id in d.regions[id].history:
			if not d.towers.has(tower_id):
				return false
	return true

func number(value: Variant, minimum: float = 0.0, maximum: float = Balance.MAX_MONEY, integer: bool = false) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(value) and value >= minimum and value <= maximum and (not integer or value == floor(value))

func valid_coordinate(value: Variant) -> bool:
	if not value is String:
		return false
	var parts: PackedStringArray = value.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return false
	return str(int(parts[0])) + "," + str(int(parts[1])) == value and abs(int(parts[0])) < 100000000 and abs(int(parts[1])) < 100000000
