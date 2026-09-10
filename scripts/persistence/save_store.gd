class_name VigilSaveStore
extends RefCounted

var last_error := ""

func delete_files(path: String) -> bool:
	# Remove fallback candidates first so a deleted slot cannot recover itself.
	for suffix in [".tmp", ".bak", ".cloud-outbox", ""]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate) and DirAccess.remove_absolute(candidate) != OK:
			last_error = "Couldn't delete this saved game completely. Please retry."
			return false
	last_error = ""
	return true

func write(path: String, data: Dictionary) -> bool:
	# Validate before opening .tmp: it may be the only recoverable snapshot.
	if not valid_data(data):
		last_error = "Couldn't save invalid progress. Your previous save is safe."
		return false
	var payload := JSON.stringify(data, "", true, true)
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
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String: return {}
	if envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK: return {}
	var value: Variant = parser.data
	return value if value is Dictionary and valid_data(value) else {}

func valid_data(_data: Dictionary) -> bool:
	return false

func number(value: Variant, minimum: float = 0.0, maximum: float = Balance.MAX_MONEY, integer: bool = false) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(value) and value >= minimum and value <= maximum and (not integer or value == floor(value))

static func valid_coordinate(value: Variant) -> bool:
	if not value is String:
		return false
	var parts: PackedStringArray = value.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return false
	return str(int(parts[0])) + "," + str(int(parts[1])) == value and abs(int(parts[0])) < 100000000 and abs(int(parts[1])) < 100000000

func valid_loadout(d: Dictionary, max_tower_level: int = 4) -> bool:
	if not d.get("towers") is Dictionary or not d.get("regions") is Dictionary or not number(d.get("next_tower"), 1, 1.0e15, true) or not number(d.get("balance")): return false
	const Relics = preload("res://scripts/gameplay/progression/relics.gd")
	var inventory: Variant = d.get("relics", {})
	if not inventory is Dictionary:
		return false
	for relic_id in inventory:
		if not relic_id is String or not inventory[relic_id] is String or not Relics.DEFINITIONS.has(inventory[relic_id]):
			return false
		var parts: PackedStringArray = relic_id.split("#")
		if parts.size() > 2 or not valid_coordinate(parts[0]) or (parts.size() == 2 and parts[1] != inventory[relic_id]):
			return false
	var equipped := {}
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
		if d.version == Balance.VERSION:
			var branch: Variant = t.get("branch", "")
			if not branch is String or (t.level == 4 and not Balance.valid_branch(t.kind, branch)) or (t.level != 4 and branch != ""):
				return false
		if not number(t.pad, 0, VigilWorld.MAX_GROUND_PAD, true) or not number(t.level, 1, max_tower_level, true) or not number(t.earnings) or not number(t.cooldown, 0, maxf(10.0, Balance.TUNING_FIELDS.towers.period.max)) or not number(t.angle, -TAU, TAU):
			return false
		var relic_id: Variant = t.get("relic", "")
		if not relic_id is String or (relic_id != "" and (not inventory.has(relic_id) or equipped.has(relic_id))):
			return false
		if relic_id != "":
			equipped[relic_id] = true
		var socket := str(t.region) + "/" + str(int(t.pad))
		if not t.get("target_mode", "first") is String or not Balance.TARGET_MODES.has(t.get("target_mode", "first")):
			return false
		if t.has("rebuild_remaining") and not number(t.rebuild_remaining, 0, Balance.MAX_REBUILD_SECONDS):
			return false
		if occupied.has(socket):
			return false
		occupied[socket] = true
	return true
